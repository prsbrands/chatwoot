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
import time

import httpx
from loguru import logger
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import LLMRunFrame, TTSSpeakFrame
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.runner import PipelineRunner
from pipecat.pipeline.task import PipelineParams, PipelineTask
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
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
from pipecat.turns.user_mute.mute_until_first_bot_complete_user_mute_strategy import (
    MuteUntilFirstBotCompleteUserMuteStrategy,
)
from pipecat.turns.user_stop.speech_timeout_user_turn_stop_strategy import (
    SpeechTimeoutUserTurnStopStrategy,
)
from pipecat.turns.user_turn_strategies import UserTurnStrategies

from .chatwoot import ConfigError, report_call


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
            ),
        )

    if style == "openai":
        return OpenAISTTService(
            api_key=config["api_key"],
            base_url=config["base_url"],
            settings=OpenAISTTService.Settings(model=config["model"], language=language),
        )

    raise ConfigError(f"transcription provider speaks '{style}'; wire up Deepgram or an OpenAI-compatible one")


def _llm(config: dict) -> OpenAILLMService:
    style = config["api_style"]
    if style != "openai":
        raise ConfigError(f"language model provider speaks '{style}'; voice needs an OpenAI-compatible one")

    return OpenAILLMService(
        api_key=config["api_key"],
        base_url=config["base_url"],
        settings=OpenAILLMService.Settings(
            model=config["model"],
            temperature=config["temperature"],
            max_tokens=config["max_tokens"],
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

    # A frase de abertura entra no histórico como fala do próprio bot. Sem isso
    # ela é só áudio: o modelo não sabe que já atendeu e se apresenta de novo na
    # resposta seguinte.
    opening = persona.get("first_message")
    messages = [{"role": "system", "content": persona["system_prompt"]}]
    if opening:
        messages.append({"role": "assistant", "content": opening})

    context = LLMContext(messages=messages)
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
            user_turn_strategies=UserTurnStrategies(
                stop=[
                    SpeechTimeoutUserTurnStopStrategy(
                        user_speech_timeout=persona["endpoint_ms"] / 1000
                    )
                ]
            ),
            # Rede de segurança para quando a transcrição não volta (ruído de
            # linha). O padrão de 5 s é uma eternidade numa chamada.
            user_turn_stop_timeout=2.0,
            # A saudação nunca é interrompível, mesmo em persona interrompível:
            # quem atende costuma dizer "alô?" assim que a linha abre, e isso
            # cortava a abertura no meio. Depois da primeira fala do bot, vale a
            # escolha da persona.
            user_mute_strategies=[MuteUntilFirstBotCompleteUserMuteStrategy()]
            if persona["interruptible"]
            else [AlwaysUserMuteStrategy()],
        ),
    )

    pipeline = Pipeline(
        [
            transport.input(),
            VADProcessor(vad_analyzer=vad_analyzer),
            _stt(config["stt"], stt_language, persona["endpoint_ms"]),
            aggregators.user(),
            _llm(config["llm"]),
            _tts(config["tts"], tts_language),
            transport.output(),
            aggregators.assistant(),
        ]
    )

    # As métricas são o que vai alimentar o custo por minuto e a latência na
    # Fase 4 — ligar depois seria refazer a instrumentação.
    task = PipelineTask(
        pipeline,
        params=PipelineParams(enable_metrics=True, enable_usage_metrics=True),
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
            "summary": await _summarise(context, config["llm"]),
        }
    )


# O prompt do sistema é instrução, não conversa, e a abertura escrita já está no
# histórico como fala do bot — as duas ficam de fora do transcrito.
def _transcript_of(context: LLMContext) -> list[dict]:
    return [
        {"role": message["role"], "content": message["content"]}
        for message in context.get_messages()
        if message.get("role") in ("user", "assistant") and isinstance(message.get("content"), str)
    ]


async def _summarise(context: LLMContext, llm: dict) -> str:
    """Duas linhas sobre o que a chamada rendeu, para quem for retomar o lead.

    Best-effort de propósito: um resumo que falha não pode levar junto a
    transcrição, que é o que realmente importa registrar.
    """
    turns = _transcript_of(context)
    if not turns:
        return ""

    conversation = "\n".join(f"{t['role']}: {t['content']}" for t in turns)
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                f"{llm['base_url'].rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {llm['api_key']}"},
                json={
                    "model": llm["model"],
                    "max_tokens": 200,
                    "messages": [
                        {
                            "role": "system",
                            "content": (
                                "Resume esta llamada telefónica en dos o tres frases, en español. "
                                "Di quién llamó, qué necesita y cuál es el siguiente paso. "
                                "Sin preámbulo."
                            ),
                        },
                        {"role": "user", "content": conversation},
                    ],
                },
            )
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"].strip()
    except Exception as error:
        logger.warning(f"summary skipped: {type(error).__name__}: {error}")
        return ""
