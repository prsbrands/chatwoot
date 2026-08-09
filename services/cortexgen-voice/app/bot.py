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
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.services.openai.llm import OpenAILLMService
from pipecat.services.openai.stt import OpenAISTTService
from pipecat.transcriptions.language import Language
from pipecat.transports.websocket.fastapi import (
    FastAPIWebsocketParams,
    FastAPIWebsocketTransport,
)
from pipecat.turns.user_mute.always_user_mute_strategy import AlwaysUserMuteStrategy

from .chatwoot import ConfigError


def _language(code: str | None) -> Language | None:
    if not code:
        return None
    try:
        return Language(code)
    except ValueError as error:
        raise ConfigError(
            f"'{code}' is not a language the voice stack knows — use a code like 'es' or 'pt-BR'"
        ) from error


def _stt(config: dict, language: Language | None) -> OpenAISTTService:
    style = config["api_style"]
    if style != "openai":
        raise ConfigError(f"transcription provider speaks '{style}'; only OpenAI-compatible is wired up")

    return OpenAISTTService(
        api_key=config["api_key"],
        base_url=config["base_url"],
        settings=OpenAISTTService.Settings(model=config["model"], language=language),
    )


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


async def run_call(websocket, stream_id: str, call_id: str, config: dict) -> None:
    """Conduz uma chamada até o WebSocket fechar."""
    persona = config["persona"]
    language = _language(persona.get("language"))

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

    context = LLMContext(
        messages=[{"role": "system", "content": persona["system_prompt"]}]
    )
    # Interromper é o padrão do Pipecat. Uma persona não-interrompível é a que
    # cala quem ligou enquanto o bot fala.
    aggregators = LLMContextAggregatorPair(
        context,
        user_params=LLMUserAggregatorParams(
            vad_analyzer=vad_analyzer,
            user_mute_strategies=[] if persona["interruptible"] else [AlwaysUserMuteStrategy()],
        ),
    )

    pipeline = Pipeline(
        [
            transport.input(),
            VADProcessor(vad_analyzer=vad_analyzer),
            _stt(config["stt"], language),
            aggregators.user(),
            _llm(config["llm"]),
            _tts(config["tts"], language),
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
        opening = persona.get("first_message")
        await task.queue_frames([TTSSpeakFrame(opening) if opening else LLMRunFrame()])

    @transport.event_handler("on_client_disconnected")
    async def _on_disconnected(_transport, _client):
        await task.cancel()

    # Uma chamada abandonada em silêncio já é encerrada pelo próprio
    # PipelineTask (idle_timeout_secs), que é o caso que custa por minuto sem
    # ninguém do outro lado.
    logger.info(f"call {call_id} started as '{persona['slug']}'")
    await PipelineRunner(handle_sigint=False).run(task)
    logger.info(f"call {call_id} finished")
