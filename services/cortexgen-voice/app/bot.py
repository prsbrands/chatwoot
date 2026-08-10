"""O laço de áudio de uma chamada.

A ordem do pipeline é a chamada inteira em uma linha: o áudio entra, o VAD
decide onde termina o turno de quem ligou, o trecho vira texto, o texto entra no
contexto, o modelo responde, a resposta vira voz e volta pelo mesmo WebSocket.

O VAD roda aqui dentro, de graça, porque a transcrição que usamos é por trecho e
não por streaming: o Deepgram nova-3 chega pelo OpenRouter no endpoint compatível
com OpenAI, que recebe um arquivo e devolve o texto. Quem recorta esse arquivo no
lugar certo é o Silero, local.
"""

import asyncio
import json
import time

import httpx
from loguru import logger
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import LLMRunFrame, TTSSpeakFrame
from pipecat.observers.user_bot_latency_observer import UserBotLatencyObserver
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
    FilterIncompleteUserTurnStrategies,
    LLMContextAggregatorPair,
    LLMUserAggregatorParams,
)
from pipecat.processors.audio.vad_processor import VADProcessor
from pipecat.serializers.twilio import TwilioFrameSerializer
from pipecat.services.deepgram.stt import DeepgramSTTService
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.services.openai.stt import OpenAISTTService
from pipecat.transcriptions.language import Language
from pipecat.transports.websocket.fastapi import (
    FastAPIWebsocketParams,
    FastAPIWebsocketTransport,
)
from pipecat.turns.user_mute.always_user_mute_strategy import AlwaysUserMuteStrategy
from pipecat.turns.user_start.min_words_user_turn_start_strategy import (
    MinWordsUserTurnStartStrategy,
)
from pipecat.turns.user_start.vad_user_turn_start_strategy import (
    VADUserTurnStartStrategy,
)
from pipecat.turns.user_stop.speech_timeout_user_turn_stop_strategy import (
    SpeechTimeoutUserTurnStopStrategy,
)
from pipecat.turns.user_turn_completion_mixin import (
    USER_TURN_COMPLETION_INSTRUCTIONS,
    UserTurnCompletionConfig,
)
from pipecat.turns.user_turn_strategies import UserTurnStrategies

from .chatwoot import ConfigError, report_call
from .metrics import CallMetrics


# O Pipecat já ensina o modelo a marcar se quem fala terminou. Falta o caso que
# nos custou uma ligação: ditar letra por letra, com pausas longas entre elas,
# que o silêncio sozinho lê como fim de frase.
SPELLING_INSTRUCTIONS = f"""{USER_TURN_COMPLETION_INSTRUCTIONS}

DICTATION — treat this as INCOMPLETE SHORT (○), always:
- The user announced they are about to spell or dictate something
  ("voy a deletrear", "te lo deletreo", "apunta", "let me spell that")
- The last thing you received is loose letters, digits or fragments
  ("a r r o", "jota o ese e", "cero seis")
- A part-built email, domain or document number that is not usable yet
Only mark ✓ once the spelled item is whole. Someone reciting an email pauses
between letters, and answering into that pause is how you make them start over.
"""


def _turn_strategies(persona: dict) -> UserTurnStrategies:
    """Quem decide que o turno de quem ligou acabou.

    Por silêncio sempre; e, quando a persona pede, com o modelo julgando se a
    frase realmente terminou antes de o bot responder. Esse julgamento sai de
    graça: é a mesma chamada que já gera a resposta.
    """
    detector = [
        SpeechTimeoutUserTurnStopStrategy(user_speech_timeout=persona["endpoint_ms"] / 1000)
    ]

    # Quem abre o turno é o áudio, não o texto.
    #
    # O padrão do Pipecat também deixa uma transcrição abrir turno, e isso vira
    # uma armadilha com os parciais do Deepgram ligados: cada fragmento de frase
    # abria um turno, que fechava sozinho e ganhava resposta. Numa chamada real
    # o bot perguntou quatro vezes a mesma coisa em quinze segundos, sem deixar
    # quem ligou terminar uma frase.
    #
    # Com um mínimo de palavras é o texto que manda, de propósito: aí a questão
    # é justamente quantas palavras foram ditas antes de valer como interrupção.
    min_words = persona.get("interrupt_min_words") or 0
    start = (
        [MinWordsUserTurnStartStrategy(min_words=min_words, use_interim=True)]
        if min_words > 0
        else [VADUserTurnStartStrategy()]
    )

    if not persona.get("wait_for_complete_turn", True):
        return UserTurnStrategies(start=start, stop=detector)

    return FilterIncompleteUserTurnStrategies(
        start=start,
        stop=detector,
        config=UserTurnCompletionConfig(instructions=SPELLING_INSTRUCTIONS),
    )


def _language(code: str | None):
    """Idioma como o fornecedor espera receber.

    Os dois campos vêm de um Select no painel, então não há digitação livre para
    validar aqui. Códigos fora do enum do Pipecat passam adiante como string —
    é o caso de 'multi', que o Deepgram entende (troca de idioma no meio da
    chamada) e o enum não conhece.
    """
    if not code:
        return None
    try:
        return Language(code)
    except ValueError:
        return code


def _stt(config: dict, language: Language | None, endpoint_ms: int):
    """Transcrição, em streaming quando o fornecedor permite.

    O Deepgram direto fala WebSocket e devolve texto enquanto a pessoa ainda
    fala. Pelo OpenRouter o mesmo modelo chega no endpoint de arquivo, e o turno
    só é transcrito depois de fechado — o que custa uns 300 ms por resposta.
    """
    style = config["api_style"]

    if style == "deepgram":
        return DeepgramSTTService(
            api_key=config["api_key"],
            settings=DeepgramSTTService.Settings(
                model=config["model"],
                language=language,
                # O mesmo "fim de turno" da persona, agora decidido pelo próprio
                # Deepgram, que ouve o áudio em vez de só cronometrar silêncio.
                endpointing=endpoint_ms,
                # Sem estes dois o Deepgram só devolve texto quando ele decide
                # que a fala acabou — e numa linha telefônica, com ruído de
                # fundo contínuo, esse momento pode não chegar: uma chamada real
                # ficou 17 s esperando a transcrição de uma palavra. Os parciais
                # mantêm o texto fluindo e o `utterance_end_ms` é o limite duro
                # que força o fechamento do trecho.
                interim_results=True,
                utterance_end_ms=1000,
            ),
        )

    if style == "openai":
        return OpenAISTTService(
            api_key=config["api_key"],
            base_url=config["base_url"],
            settings=OpenAISTTService.Settings(model=config["model"], language=language),
        )

    raise ConfigError(f"transcription provider speaks '{style}'; wire up Deepgram or an OpenAI-compatible one")


def _model_cascade(config: dict, fallback: dict | None) -> list[str] | None:
    """Principal e reserva num pedido só, quando os dois moram no mesmo lugar."""
    if not fallback:
        return None

    if fallback["base_url"] != config["base_url"]:
        logger.warning(
            f"fallback on {fallback['base_url']} ignored: a call cannot switch providers mid-stream"
        )
        return None

    return [config["model"], fallback["model"]]


def _llm_extras(config: dict, fallback: dict | None) -> dict:
    """Campos que o Pipecat repassa como kwargs do SDK da OpenAI.

    O SDK não conhece `models` — quem entende é o OpenRouter. Campos assim vão
    em `extra_body`, que é a porta do SDK para o que só o fornecedor conhece.
    Passar direto derruba toda chamada com "unexpected keyword argument".
    """
    models = _model_cascade(config, fallback)
    return {"extra_body": {"models": models}} if models else {}


def _llm(config: dict, fallback: dict | None) -> OpenAILLMService:
    """O modelo que responde, com rede embaixo.

    Duas redes, para duas quedas diferentes. Modelo que não responde a tempo cai
    no retry por timeout — é a chamada parada em silêncio enquanto quem ligou
    espera. Modelo indisponível ou sobrecarregado cai no de reserva, pedindo a
    troca ao próprio roteador: um único request lista os dois modelos e o
    roteador desce para o segundo sem uma segunda ida à rede.

    Reserva em fornecedor diferente não é coberta aqui — trocar de endpoint no
    meio de um stream é outra história, e a persona oferece "igual ao principal"
    como padrão justamente porque é esse o caminho de produção.
    """
    style = config["api_style"]
    if style != "openai":
        raise ConfigError(f"language model provider speaks '{style}'; voice needs an OpenAI-compatible one")

    return OpenAILLMService(
        api_key=config["api_key"],
        base_url=config["base_url"],
        retry_on_timeout=True,
        # Seis segundos era o número da ElevenLabs para o painel deles. Ao
        # telefone, seis segundos de silêncio já são uma ligação perdida — uma
        # chamada real esperou 5,4 s por um primeiro token e quem ligou desligou
        # antes de ouvir a resposta.
        retry_timeout_secs=3.0,
        settings=OpenAILLMService.Settings(
            model=config["model"],
            temperature=config["temperature"],
            max_tokens=config["max_tokens"],
            extra=_llm_extras(config, fallback),
        ),
    )


def _tts(config: dict, language: Language | None) -> ElevenLabsTTSService:
    style = config["api_style"]
    if style != "elevenlabs":
        raise ConfigError(f"voice provider speaks '{style}'; only ElevenLabs is wired up")

    return ElevenLabsTTSService(
        api_key=config["api_key"],
        settings=ElevenLabsTTSService.Settings(
            voice=config["voice_id"],
            model=config["model"],
            language=language,
        ),
    )


async def run_call(websocket, stream_id: str, call_id: str, from_number: str, config: dict) -> None:
    """Conduz uma chamada até o WebSocket fechar."""
    persona = config["persona"]
    # Escutar e falar são decisões separadas: o transcritor pode estar em
    # 'multi' enquanto a voz segue o texto que o modelo escreveu.
    stt_language = _language(persona.get("stt_language"))
    tts_language = _language(persona.get("language"))

    # auto_hang_up ficaria dependente de credencial da Twilio aqui dentro. Não
    # precisa: quando este WebSocket fecha, o `<Connect>` acaba e a chamada cai.
    serializer = TwilioFrameSerializer(
        stream_sid=stream_id,
        call_sid=call_id,
        params=TwilioFrameSerializer.InputParams(auto_hang_up=False),
    )

    transport = FastAPIWebsocketTransport(
        websocket=websocket,
        params=FastAPIWebsocketParams(
            audio_in_enabled=True,
            audio_out_enabled=True,
            add_wav_header=False,
            serializer=serializer,
        ),
    )

    # O silêncio que encerra o turno de quem ligou. Curto demais corta quem
    # pensa no meio da frase; longo demais parece surdez. O mesmo analisador
    # serve ao processador de áudio e ao agregador, que decide os turnos.
    vad_analyzer = SileroVADAnalyzer(
        params=VADParams(stop_secs=persona["endpoint_ms"] / 1000)
    )

    # A abertura não é semeada no contexto: o agregador já registra o que o bot
    # fala, inclusive a saudação. Semear além disso a duplicava no histórico e
    # no transcrito da conversa.
    opening = persona.get("first_message")
    context = LLMContext(messages=[{"role": "system", "content": persona["system_prompt"]}])
    # Interromper é o padrão do Pipecat. Uma persona não-interrompível é a que
    # cala quem ligou enquanto o bot fala.
    #
    # O fim de turno é por silêncio, e não pelo Smart Turn que o Pipecat usa por
    # padrão. O modelo semântico julgava espanhol ao telefone como frase
    # inacabada e devolvia INCOMPLETE, então o turno só fechava no timeout de 5 s
    # — tempo suficiente para quem ligou achar que a linha caiu, falar de novo e
    # essa fala interromper a resposta que finalmente vinha. Silêncio permanente.
    # Com o silêncio como critério, o "fim de turno" da persona manda de fato.
    aggregators = LLMContextAggregatorPair(
        context,
        user_params=LLMUserAggregatorParams(
            vad_analyzer=vad_analyzer,
            user_turn_strategies=_turn_strategies(persona),
            # Rede de segurança para quando a transcrição não volta (ruído de
            # linha). O padrão de 5 s é uma eternidade numa chamada.
            user_turn_stop_timeout=2.0,
            # Quem liga nunca é silenciado durante a saudação.
            #
            # Já foi: para a abertura não ser cortada por um "alô?". Mas a
            # abertura pergunta o nome, e leva seis segundos fazendo isso —
            # quem responde no meio, que é o normal, tinha a resposta jogada
            # fora, e a máquina de turnos ficava esperando um turno que nunca
            # começou. Uma chamada real morreu em 62 segundos de silêncio com a
            # resposta já transcrita e parada. Abertura cortada é um arranhão;
            # chamada morta é a chamada.
            user_mute_strategies=[] if persona["interruptible"] else [AlwaysUserMuteStrategy()],
        ),
    )

    pipeline = Pipeline(
        [
            transport.input(),
            VADProcessor(vad_analyzer=vad_analyzer),
            _stt(config["stt"], stt_language, persona["endpoint_ms"]),
            aggregators.user(),
            _llm(config["llm"], config.get("llm_fallback")),
            _tts(config["tts"], tts_language),
            transport.output(),
            aggregators.assistant(),
        ]
    )

    # O que a chamada consumiu, e o que quem ligou esperou. O observador de
    # latência mede da última sílaba dela à primeira do bot — que é a espera
    # sentida, não a soma dos tempos internos.
    metrics = CallMetrics()
    latency = UserBotLatencyObserver()

    @latency.event_handler("on_latency_measured")
    async def _on_latency(_observer, seconds):
        metrics.record_latency(seconds)

    task = PipelineTask(
        pipeline,
        params=PipelineParams(enable_metrics=True, enable_usage_metrics=True),
        observers=[metrics, latency],
        conversation_id=call_id,
    )

    @transport.event_handler("on_client_connected")
    async def _on_connected(_transport, _client):
        # Falar em cima do "alô" faz o cliente pedir para repetir a chamada
        # inteira.
        await asyncio.sleep(persona["greeting_delay_ms"] / 1000)
        # Com abertura escrita, ela é falada como está — sem passar pelo modelo,
        # que é o que faz a primeira frase ser sempre a mesma e sempre rápida.
        await task.queue_frames([TTSSpeakFrame(opening) if opening else LLMRunFrame()])

    @transport.event_handler("on_client_disconnected")
    async def _on_disconnected(_transport, _client):
        await task.cancel()

    # Uma chamada abandonada em silêncio já é encerrada pelo próprio
    # PipelineTask (idle_timeout_secs), que é o caso que custa por minuto sem
    # ninguém do outro lado.
    logger.info(f"call {call_id} started as '{persona['slug']}'")
    started_at = time.monotonic()
    await PipelineRunner(handle_sigint=False).run(task)
    duration = int(time.monotonic() - started_at)
    logger.info(f"call {call_id} finished after {duration}s")

    await report_call(
        {
            "call_sid": call_id,
            "phone_number": config["call"]["phone_number"],
            "from_number": from_number,
            "duration_seconds": duration,
            "transcript": _transcript_of(context),
            "metrics": metrics.as_payload(),
            **await _read_the_call(context, config["llm"]),
        }
    )


# O prompt do sistema é instrução, não conversa, e fica de fora do transcrito.
#
# As marcas de fim de turno (✓ ○ ◐) o Pipecat já tira do que vai para a voz, mas
# não do histórico — e o transcrito é o que alguém de vendas lê depois. Um turno
# que era só "○" nem chegou a ser fala.
TURN_MARKERS = "✓○◐"


def _transcript_of(context: LLMContext) -> list[dict]:
    turns = []
    for message in context.get_messages():
        if message.get("role") not in ("user", "assistant"):
            continue
        if not isinstance(message.get("content"), str):
            continue

        content = message["content"].lstrip(TURN_MARKERS).strip()
        if content:
            turns.append({"role": message["role"], "content": content})
    return turns


READING_PROMPT = """Lee esta llamada telefónica y devuelve SOLO un objeto JSON, sin texto alrededor:

{"summary": "...", "name": "...", "email": "...", "company": "...", "city": "...", "whatsapp": "..."}

- summary: dos o tres frases en español. Quién llamó, qué necesita, cuál es el siguiente paso.
- name: el nombre de la persona tal como lo dijo. null si no lo dio.
- email: solo si lo dictó. Une las letras deletreadas. null si no lo dio.
- company: el nombre de la empresa. Une las letras si lo deletreó. null si no lo dio.
- city: solo si dijo en qué ciudad está. Un país, un dominio (.pa, .br) o un
  prefijo telefónico NO son una ciudad. null si no la dijo.
- whatsapp: solo si dio un número distinto del que llamó. null en cualquier otro caso.

REGLA ABSOLUTA: copia lo que oíste, nunca lo completes. Si el correo quedó a
medias, si el nombre de la empresa salió cortado o si no entendiste, devuelve
null. Un dato inventado entra en el CRM como si fuera cierto y alguien lo usa.
"""


async def _read_the_call(context: LLMContext, llm: dict) -> dict:
    """Resumo e os dados do lead, numa passada só.

    Quem liga dita nome, empresa e e-mail em voz alta, muitas vezes soletrando.
    Extrair isso aqui é o que transforma a chamada em contato preenchido em vez
    de um número de telefone sem nome.

    Best-effort de propósito: uma extração que falha não pode levar junto a
    transcrição, que é o que realmente importa registrar.
    """
    turns = _transcript_of(context)
    if not turns:
        return {}

    conversation = "\n".join(f"{t['role']}: {t['content']}" for t in turns)
    try:
        async with httpx.AsyncClient(timeout=25) as client:
            response = await client.post(
                f"{llm['base_url'].rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {llm['api_key']}"},
                json={
                    "model": llm["model"],
                    "max_tokens": 400,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {"role": "system", "content": READING_PROMPT},
                        {"role": "user", "content": conversation},
                    ],
                },
            )
        response.raise_for_status()
        raw = response.json()["choices"][0]["message"]["content"]
        return {key: value for key, value in json.loads(raw).items() if value}
    except Exception as error:
        logger.warning(f"call reading skipped: {type(error).__name__}: {error}")
        return {}
