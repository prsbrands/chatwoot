"""Instancia cada peça do pipeline com configuração falsa.

Não faz chamada nem gasta crédito: só prova que os nomes e as assinaturas
batem com a versão do Pipecat que está instalada. Um kwarg errado aqui só
apareceria com o cliente na linha.

    docker run --rm cortexgen-voice:test python smoke.py
"""

from pipecat.pipeline.task import PipelineParams
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService

from app.bot import _language, _llm, _stt, _tts

FAKE = {
    "stt": {"api_style": "openai", "api_key": "k", "base_url": "https://openrouter.ai/api/v1", "model": "deepgram/nova-3"},
    "stt_direct": {"api_style": "deepgram", "api_key": "k", "base_url": "", "model": "nova-3"},
    "llm": {"api_style": "openai", "api_key": "k", "base_url": "https://openrouter.ai/api/v1",
            "model": "deepseek/deepseek-v4-flash-0731", "temperature": 0.6, "max_tokens": 400},
    "tts": {"api_style": "elevenlabs", "api_key": "k", "voice_id": "v", "model": "eleven_flash_v2_5"},
}

assert "enable_usage_metrics" in PipelineParams.model_fields, "usage metrics moved"
for field in ("voice", "model", "language"):
    assert field in ElevenLabsTTSService.Settings.__dataclass_fields__, f"ElevenLabs '{field}' moved"

language = _language("es")
print("language:", language)

print("stt via openrouter:", type(_stt(FAKE["stt"], language, 600)).__name__)
print("stt via deepgram:  ", type(_stt(FAKE["stt_direct"], language, 600)).__name__)
print("llm:", type(_llm(FAKE["llm"])).__name__)
print("tts:", type(_tts(FAKE["tts"], language)).__name__)

# O que mudou entre versões do Pipecat: onde mora o VAD e como se desliga a
# interrupção. Tudo menos o transport, que precisa de um WebSocket de verdade.
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.processors.aggregators.llm_context import LLMContext
from pipecat.processors.aggregators.llm_response_universal import (
    LLMContextAggregatorPair,
    LLMUserAggregatorParams,
)
from pipecat.processors.audio.vad_processor import VADProcessor
from pipecat.turns.user_mute.always_user_mute_strategy import AlwaysUserMuteStrategy

analyzer = SileroVADAnalyzer(params=VADParams(stop_secs=0.6))
pair = LLMContextAggregatorPair(
    LLMContext(messages=[{"role": "system", "content": "hola"}]),
    user_params=LLMUserAggregatorParams(
        vad_analyzer=analyzer, user_mute_strategies=[AlwaysUserMuteStrategy()]
    ),
)
print("vad:", type(VADProcessor(vad_analyzer=analyzer)).__name__)
print("aggregators:", type(pair.user()).__name__, type(pair.assistant()).__name__)

try:
    _stt({**FAKE["stt"], "api_style": "nonsense"}, language, 600)
    raise SystemExit("stt accepted a provider it cannot speak to")
except Exception as error:
    print("stt rejects unknown api_style:", type(error).__name__)

try:
    _tts({**FAKE["tts"], "api_style": "nonsense"}, language)
    raise SystemExit("tts accepted a provider it cannot speak to")
except Exception as error:
    print("tts rejects unknown api_style:", type(error).__name__)

print("\nSMOKE OK")
