"""O laço de áudio de uma chamada.

A ordem do pipeline é a chamada inteira em uma linha: o áudio entra, vira texto,
o texto entra no contexto, o modelo responde, a resposta vira voz e volta pelo
mesmo WebSocket.

**Quem decide de quem é a vez muda conforme o transcritor**, e é a diferença
que mais importa aqui:

- **Deepgram Flux** (`flux-general-*`, `/v2/listen`) traz a máquina de turnos
  dentro do serviço e emite os quadros de início e fim de fala. O pipeline só
  repassa. É o caminho recomendado para telefonia.
- **Qualquer outro** obriga a montar essa máquina deste lado: VAD local do
  Silero, silêncio cronometrado e, opcionalmente, um portão por LLM. Cada peça
  dessa pilha já derrubou uma chamada real — ver a skill `pipecat`.
"""

import asyncio
import json
import re
import time

import httpx
from loguru import logger
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import (
    BotStartedSpeakingFrame,
    BotStoppedSpeakingFrame,
    InputAudioRawFrame,
    LLMRunFrame,
    TTSSpeakFrame,
    TTSTextFrame,
)
from pipecat.observers.base_observer import BaseObserver, FramePushed
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor
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
from pipecat.services.deepgram.flux.stt import DeepgramFluxSTTService
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
from pipecat.turns.user_start.external_user_turn_start_strategy import (
    ExternalUserTurnStartStrategy,
)
from pipecat.turns.user_start.min_words_user_turn_start_strategy import (
    MinWordsUserTurnStartStrategy,
)
from pipecat.turns.user_start.vad_user_turn_start_strategy import (
    VADUserTurnStartStrategy,
)
from pipecat.turns.user_stop.external_user_turn_stop_strategy import (
    ExternalUserTurnStopStrategy,
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


def uses_flux(stt: dict) -> bool:
    """O Flux é da Deepgram mas é outro produto: `/v2/listen`, com turnos próprios."""
    return stt["api_style"] == "deepgram" and str(stt.get("model") or "").startswith("flux")


def _flux_turn_strategies() -> UserTurnStrategies:
    """Com o Flux, quem decide o turno é quem ouve o áudio.

    Ele emite `UserStartedSpeakingFrame` e `UserStoppedSpeakingFrame` a partir
    da própria máquina de turnos — que enxerga a forma de onda, não só o
    silêncio. As estratégias `External` apenas repassam essa decisão.

    Some daqui tudo o que existia para suprir o que o Nova não faz: silêncio
    cronometrado, modelo semântico de turno e o portão por LLM. Cada um desses
    já derrubou uma chamada real.
    """
    return UserTurnStrategies(
        start=[ExternalUserTurnStartStrategy()],
        # O `timeout` padrão de 0,5 s é uma janela de espera por transcrições
        # atrasadas ou partidas em pedaços — pensada para quem entrega texto
        # depois do fim da fala. O Flux entrega o transcrito **junto** com o
        # `EndOfTurn`, então esse meio segundo era espera por algo que já
        # chegou: ele aparecia cravado em todos os turnos de todas as chamadas,
        # entre `EndOfTurn` e `User turn inference triggered`, dentro de uma
        # latência sentida de 2,26 s contra alvo de 1,5 s.
        stop=[ExternalUserTurnStopStrategy(timeout=0.2)],
    )


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


def _stt(config: dict, language: Language | None, endpoint_ms: int, eot_threshold: float = 0.8):
    """Transcrição, em streaming quando o fornecedor permite.

    O Deepgram direto fala WebSocket e devolve texto enquanto a pessoa ainda
    fala. Pelo OpenRouter o mesmo modelo chega no endpoint de arquivo, e o turno
    só é transcrito depois de fechado — o que custa uns 300 ms por resposta.
    """
    style = config["api_style"]

    if uses_flux(config):
        # `/v2/listen`. Não tem `endpointing`, `interim_results` nem
        # `utterance_end_ms`: os limiares são confiança de fim de turno, não
        # tempo de silêncio. `eot_timeout_ms` é o teto duro.
        #
        # `language` não existe aqui: o `_build_query_string` do Flux monta
        # model, sample_rate, encoding, thresholds, keyterm, tag e
        # `language_hint` — e mais nada. O `multi` que a persona manda nunca
        # chegou à Deepgram; quem segurava o multilíngue era só o sufixo do
        # modelo, sozinho e sem viés nenhum.
        #
        # Sem viés, numa linha de 8 kHz, ele passeia: quatro segundos de
        # espanhol voltaram como "Es traurige Saussurer gravata paraffins de
        # quali ditti" — alemão, francês e italiano na mesma frase. O bot
        # respondeu ao que leu, e quem ligou ouviu um assunto que não era o
        # dele. As duas línguas abaixo são as que esta instalação fala; vira
        # campo de persona quando uma segunda instalação falar outras.
        return DeepgramFluxSTTService(
            api_key=config["api_key"],
            settings=DeepgramFluxSTTService.Settings(
                model=config["model"],
                language_hints=[Language.ES, Language.PT],
                # Campo da persona desde que o coletor de métricas voltou a
                # medir: a espera do EndOfTurn é ~0,8 s de silêncio com quem
                # ligou já calado, e era o único knob gordo que estava chumbado
                # aqui — cada tentativa custava um deploy.
                #
                # 0.7, o padrão da Deepgram, fechava o turno na pausa natural de
                # quem fala em blocos: "Doutor Juan" virou 'Doutor,' + 'one.' e
                # custou três idas e voltas para capturar um nome; "Clínica Luis
                # / Soy médico / tenemos atención" virou três turnos numa frase.
                # E blips de 115 ms viravam fala, cortando o bot na primeira
                # sílaba. Por isso o padrão daqui é 0.8, não o da Deepgram.
                eot_threshold=eot_threshold,
                eager_eot_threshold=0.5,
                eot_timeout_ms=5000,
            ),
        )

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
    """Principal e reserva num pedido só, quando o fornecedor sabe fazer isso.

    Quem desce para o segundo modelo é o roteador do OpenRouter, lendo o array
    `models` no corpo. **É extensão dele, não do protocolo da OpenAI** — a API
    da OpenAI devolve `400 Unrecognized request argument supplied: models` e a
    chamada morre logo depois da saudação, que é a única fala que não passa
    pelo modelo. Foi o que aconteceu ao mudar o primário para a OpenAI direto e
    manter a reserva "igual ao primário".

    Reserva de verdade fora do OpenRouter exige um segundo request depois do
    erro, e isso é outro problema: no meio de um stream já falado pela metade.
    """
    if not fallback:
        return None

    if fallback["base_url"] != config["base_url"]:
        logger.warning(
            f"fallback on {fallback['base_url']} ignored: a call cannot switch providers mid-stream"
        )
        return None

    if "openrouter.ai" not in config["base_url"]:
        logger.warning(
            f"fallback ignored: {config['base_url']} does not take a `models` array — "
            "only OpenRouter routes to a second model inside one request"
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
        # **Um retry nunca faz quem ligou esperar menos** — ele descarta o
        # request em curso e refaz o prefill do zero. Só compensa quando o
        # modelo emudeceu de vez; contra modelo apenas lento, ele dobra a conta.
        #
        # Com 3 s isso virou o defeito: numa chamada real três de quatro turnos
        # bateram no limite, e a espera foi de 9,8 s, 7,9 s e 7,6 s. O único
        # turno que não disparou retry respondeu em 1,3 s.
        #
        # 5 s fica acima de qualquer TTFB saudável medido (0,4–1,4 s) com folga
        # larga, e abaixo dos 6 s que já custaram uma ligação — quem ligou
        # desliga antes disso.
        retry_timeout_secs=5.0,
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


class SilenceUntilBotHasSpoken(FrameProcessor):
    """O transcritor só começa a ouvir quando o bot termina de se apresentar.

    Sobre o quase-silêncio de uma linha telefônica o Flux alucina uma frase
    de estoque. Cinco chamadas, sempre o mesmo esqueleto — 'estado de casa,
    suragavada para fins de Quality ID', 'Estalo já será para frente de
    Quality ID' — inclusive numa em que o microfone de quem ligou estava
    mudo. Ele declara turno em cima disso, a interrupção mata a saudação, e a
    pergunta "¿Cuál es su nombre?" nunca chega ao telefone. O bot ainda
    responde à alucinação com "No entendí bien".

    O gatilho está no primeiro segundo, **antes de o bot emitir um byte**:
    numa chamada o turno fantasma abriu 544 ms depois de a saudação começar,
    a partir de áudio capturado quando o bot ainda estava calado. Por isso
    não basta silenciar enquanto ele fala — a porteira tem de nascer fechada
    e só abrir quando a apresentação terminar. Um bot que escuta antes de
    acabar de se apresentar perde a própria pergunta.

    Fica **antes** do STT de propósito: o que não chega ao Deepgram não vira
    turno, e nada a jusante precisa saber disso. É a diferença para o mute
    que matou uma chamada em 62 s — aquele agia depois do STT e deixava um
    turno pela metade na máquina de estados; este troca bytes por silêncio e
    não guarda estado nenhum. Nada pode cortar a saudação, então o
    `BotStoppedSpeakingFrame` que abre a porteira sempre chega.

    O preço é o barge-in: enquanto o bot fala, não dá para cortá-lo, e um
    "aló" durante a abertura se perde. Quem ligou responde depois da
    pergunta — que agora ele ouve.
    """

    def __init__(self):
        super().__init__()
        self._bot_speaking = False
        self._opening_done = False
        self.frames_silenced = 0

    async def process_frame(self, frame, direction: FrameDirection):
        await super().process_frame(frame, direction)

        # O transporte de saída empurra estes dois para os dois lados, então
        # eles chegam aqui mesmo estando no fim do pipeline.
        if isinstance(frame, BotStartedSpeakingFrame):
            self._bot_speaking = True
        elif isinstance(frame, BotStoppedSpeakingFrame):
            self._bot_speaking = False
            self._opening_done = True
        elif (self._bot_speaking or not self._opening_done) and isinstance(
            frame, InputAudioRawFrame
        ):
            # Silêncio, não descarte: o Flux conta com áudio contínuo para
            # cronometrar os próprios turnos.
            self.frames_silenced += 1
            frame = InputAudioRawFrame(
                audio=bytes(len(frame.audio)),
                num_channels=frame.num_channels,
                sample_rate=frame.sample_rate,
            )

        await self.push_frame(frame, direction)


# A despedida escrita no prompt termina sempre assim, em qualquer das variações
# que ele manda adaptar — "que tengas buen día", "que tenga buenas tardes",
# "que tengan un buen día". É o que sobra de invariante quando o texto muda com
# a hora de Panamá e com o tratamento.
FAREWELL = re.compile(r"que teng\w*\s+(un\s+)?buen", re.IGNORECASE)


class HangUpAfterFarewell(BaseObserver):
    """Encerra a chamada quando o bot termina de se despedir.

    Faltava a peça inteira: o prompt escrevia a despedida e ninguém agia sobre
    ela. O serializer sobe com `auto_hang_up=False` e nada empurrava um frame de
    fim, então a linha ficava aberta até quem ligou desligar — ou até os 300 s
    de `idle_timeout_secs`, pagando Twilio e Deepgram para transmitir silêncio.

    Fechar o WebSocket basta: sem `<Connect>` a chamada cai, e por isso não é
    preciso credencial da Twilio aqui dentro.

    O gatilho é a frase e não uma decisão do modelo, pelo mesmo motivo do
    handoff de texto: desligar é irreversível, e um `end_call` alucinado corta o
    cliente no meio da frase. O preço é o inverso — se o modelo parafrasear a
    despedida, a chamada não cai sozinha. Por isso o acerto é registrado no log:
    chamada que termina sem esta linha é despedida que escapou do casamento.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.task = None
        self._saying_goodbye = False
        self._seen: set[int] = set()

    async def on_push_frame(self, data: FramePushed) -> None:
        if data.direction != FrameDirection.DOWNSTREAM:
            return

        frame = data.frame
        if isinstance(frame, TTSTextFrame):
            if frame.id in self._seen:
                return
            self._seen.add(frame.id)
            if FAREWELL.search(frame.text or ""):
                logger.info(f"farewell detected: {frame.text!r} — hanging up when it finishes")
                self._saying_goodbye = True
        # Só depois que o áudio da despedida saiu inteiro. Encerrar ao detectar
        # o texto cortaria a própria frase de tchau.
        elif isinstance(frame, BotStoppedSpeakingFrame) and self._saying_goodbye:
            self._saying_goodbye = False
            if self.task:
                await self.task.stop_when_done()


class CallerAudioOnlySerializer(TwilioFrameSerializer):
    """Só o áudio de quem ligou entra no pipeline.

    O `deserialize` do Pipecat converte **todo** evento `media` em áudio de
    entrada sem olhar a pista. Se o Twilio mandar a `outbound` junto com a
    `inbound`, a voz do próprio bot volta para o Deepgram — e aí o Flux
    anuncia que "quem ligou começou a falar" exatamente enquanto o bot fala,
    interrompe a frase no meio e ainda entrega o texto ao modelo como se
    fosse pergunta do cliente.

    Foi o que aconteceu, e uma chamada com o microfone mudo provou: a
    saudação voltou transcrita como 'suragavada para fins de Quality ID' e
    morreu em "Brands", antes de "¿Cuál es su nombre?". Com o bot calado,
    26 segundos de silêncio e nenhum turno.

    A contagem por pista fica guardada porque ela é a prova: se sair
    `outbound` no fim da chamada, a echo era nossa e acabou aqui; se sair só
    `inbound`, o eco vem da linha e a correção é outra — e cara.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.tracks_seen: dict[str, int] = {}

    async def deserialize(self, data):
        message = json.loads(data)
        if message.get("event") == "media":
            # A pista pode não vir; nesse caso é a de quem ligou.
            track = message["media"].get("track", "inbound")
            self.tracks_seen[track] = self.tracks_seen.get(track, 0) + 1
            if track != "inbound":
                return None
        return await super().deserialize(data)


async def run_call(websocket, stream_id: str, call_id: str, from_number: str, config: dict) -> None:
    """Conduz uma chamada até o WebSocket fechar."""
    persona = config["persona"]
    # Escutar e falar são decisões separadas: o transcritor pode estar em
    # 'multi' enquanto a voz segue o texto que o modelo escreveu.
    stt_language = _language(persona.get("stt_language"))
    tts_language = _language(persona.get("language"))
    flux = uses_flux(config["stt"])

    # auto_hang_up ficaria dependente de credencial da Twilio aqui dentro. Não
    # precisa: quando este WebSocket fecha, o `<Connect>` acaba e a chamada cai.
    serializer = CallerAudioOnlySerializer(
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
    # O Flux traz VAD e turnos dentro do próprio serviço; um VAD local aqui
    # seria uma segunda opinião competindo com quem ouve o áudio de verdade.
    vad_analyzer = (
        None
        if flux
        else SileroVADAnalyzer(params=VADParams(stop_secs=persona["endpoint_ms"] / 1000))
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
            user_turn_strategies=_flux_turn_strategies() if flux else _turn_strategies(persona),
            # Rede de segurança para quando a transcrição não volta, e só isso.
            #
            # Baixei para 2 s achando que era controle de latência. Não é: o
            # Deepgram leva de 2 a 5 s para entregar o trecho final, então o
            # tempo curto disparava ANTES do texto chegar, fechava o turno vazio
            # e perdia a resposta de quem ligou — que ficava esperando. Este
            # número tem de ser maior que o pior caso do STT, nunca menor.
            user_turn_stop_timeout=5.0,
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

    echo_gate = SilenceUntilBotHasSpoken()

    pipeline = Pipeline(
        [
            transport.input(),
            echo_gate,
            *([] if flux else [VADProcessor(vad_analyzer=vad_analyzer)]),
            _stt(
                config["stt"],
                stt_language,
                persona["endpoint_ms"],
                persona.get("eot_threshold") or 0.8,
            ),
            aggregators.user(),
            _llm(config["llm"], config.get("llm_fallback")),
            _tts(config["tts"], tts_language),
            transport.output(),
            aggregators.assistant(),
        ]
    )

    # O que a chamada consumiu, e o que quem ligou esperou — da última sílaba
    # dela à primeira do bot, que é a espera sentida e não a soma dos tempos
    # internos.
    #
    # O `UserBotLatencyObserver` do Pipecat fazia essa conta e foi removido: ele
    # começa a cronometrar no `VADUserStoppedSpeakingFrame`, e o Flux traz a
    # máquina de turnos dentro do próprio serviço — não há VAD no pipeline, esse
    # quadro nunca nasce, e toda chamada gravou `turns: 0` com latência nula
    # enquanto tokens e segundos de áudio eram contados normalmente. O
    # `CallMetrics` cronometra pelos quadros que o Flux realmente emite.
    metrics = CallMetrics()
    hang_up = HangUpAfterFarewell()

    task = PipelineTask(
        pipeline,
        params=PipelineParams(enable_metrics=True, enable_usage_metrics=True),
        observers=[metrics, hang_up],
        conversation_id=call_id,
    )
    # O observador precisa da tarefa que ele vai encerrar, e a tarefa precisa da
    # lista de observadores para nascer.
    hang_up.task = task

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
    logger.info(
        f"call {call_id} finished after {duration}s, audio tracks {serializer.tracks_seen}, "
        f"echo frames silenced {echo_gate.frames_silenced}"
    )

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

{"summary": "...", "name": "...", "email": "...", "company": "...", "city": "...",
 "whatsapp": "...", "timeline": "...", "interest": "...", "fit": "..."}

- summary: dos o tres frases en español. Quién llamó, qué necesita, cuál es el siguiente paso.
- name: el nombre de la persona tal como lo dijo. null si no lo dio.
- email: solo si lo dictó. Une las letras deletreadas. null si no lo dio.
- company: la empresa DE QUIEN LLAMÓ. Une las letras si la deletreó. null si no la dio.
  Nunca uses PRS Brands ni ninguna variante ("Pe-erre-ese Brands", "PRS"): esa es
  la empresa que atendió la llamada, no la del prospecto. Un rubro suelto
  ("taller automotivo", "clínica") tampoco es un nombre de empresa.
- city: solo si dijo en qué ciudad está. Un país, un dominio (.pa, .br) o un
  prefijo telefónico NO son una ciudad. null si no la dijo.
- whatsapp: solo si dio un número distinto del que llamó. null en cualquier otro caso.
- timeline: IMMEDIATE si quiere resolverlo ahora o en las próximas semanas;
  SHORT_TERM si lo hará más adelante y todavía evalúa; EXPLORATORY si solo
  está investigando.
- interest: uno de TECNOLOGIA_E_IA, MARKETING_E_BRANDING, AUTOMATIZACION_COMERCIAL,
  ATENCION_AL_CLIENTE, SISTEMAS_E_INTEGRACIONES, CONSULTORIA_ESTRATEGICA, OTRO.
- fit: LOW si no apareció un problema claro o quien llamó no es prospecto;
  MEDIUM si hay un problema real en una operación pequeña; HIGH si el problema
  tiene volumen o consecuencia declarada; PREMIUM si además hay varios canales
  o sistemas y urgencia.

REGLA ABSOLUTA: copia lo que oíste, nunca lo completes. Si el correo quedó a
medias, si el nombre de la empresa salió cortado o si no entendiste, devuelve
null. Un dato inventado entra en el CRM como si fuera cierto y alguien lo usa.
Lo mismo vale para las tres clasificaciones: null cuando la llamada no dé
elementos para decidir. "Sin clasificar" es información; una etiqueta adivinada
manda a alguien a llamar al prospecto equivocado.
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
