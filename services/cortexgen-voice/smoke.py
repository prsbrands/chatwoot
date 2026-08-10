"""Instancia cada peça do pipeline com configuração falsa.

Não faz chamada nem gasta crédito: só prova que os nomes e as assinaturas
batem com a versão do Pipecat que está instalada. Um kwarg errado aqui só
apareceria com o cliente na linha.

    docker run --rm cortexgen-voice:test python smoke.py
"""

from pipecat.pipeline.task import PipelineParams
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService

from app.bot import _flux_turn_strategies, _language, _llm, _llm_extras, _model_cascade, _stt, _tts, uses_flux

FAKE = {
    "stt": {"api_style": "openai", "api_key": "k", "base_url": "https://openrouter.ai/api/v1", "model": "deepgram/nova-3"},
    "stt_direct": {"api_style": "deepgram", "api_key": "k", "base_url": "", "model": "nova-3"},
    "stt_flux": {"api_style": "deepgram", "api_key": "k", "base_url": "", "model": "flux-general-multi"},
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
print("stt via flux:      ", type(_stt(FAKE["stt_flux"], language, 600)).__name__)

# Flux é outro produto no mesmo fornecedor: /v2/listen, com turnos próprios.
# Confundir os dois manda parâmetros que o endpoint não conhece.
assert uses_flux(FAKE["stt_flux"]) and not uses_flux(FAKE["stt_direct"])
assert type(_stt(FAKE["stt_flux"], language, 600)).__name__ == "DeepgramFluxSTTService"

# O viés de idioma tem de chegar à Deepgram, e é isso que se confere: a query
# string, não o objeto de settings. O `language` da persona ficou uma chamada
# inteira parecendo configurado e nunca saiu do processo — o `_build_query_string`
# do Flux simplesmente não o lê. Uma alucinação de idioma por turno foi o preço.
flux_query = _stt(FAKE["stt_flux"], language, 600)._build_query_string()
assert "language_hint=es" in flux_query, flux_query
assert "language_hint=pt" in flux_query, flux_query

# O limiar de fim de turno é o que separa "Doutor Juan" de 'Doutor,' + 'one.'.
# Confere o valor na query, porque é lá que ele vale — e porque um default que
# volte a 0.7 sem avisar reaparece como o bot cortando a frase de quem liga.
assert "eot_threshold=0.8" in flux_query, flux_query
print("flux query:", flux_query)

# Com Flux a máquina de turnos sai daqui: quem decide é quem ouve o áudio, e as
# estratégias External só repassam os quadros que ele emite.
fx = _flux_turn_strategies()
assert [type(x).__name__ for x in fx.start] == ["ExternalUserTurnStartStrategy"], fx.start
assert [type(x).__name__ for x in fx.stop] == ["ExternalUserTurnStopStrategy"], fx.stop

# Meio segundo de espera por transcrição atrasada é tempo morto com o Flux, que
# entrega o texto junto com o fim do turno. Confere o valor, não só o tipo: um
# default que volta silenciosamente custa 300 ms em toda resposta, e isso não
# aparece como erro em lugar nenhum.
assert fx.stop[0]._timeout == 0.2, fx.stop[0]._timeout
print("flux turns:", [type(x).__name__ for x in fx.start + fx.stop], "· debounce", fx.stop[0]._timeout)
print("llm:", type(_llm(FAKE["llm"], None)).__name__)

# Reserva no mesmo fornecedor vira lista de modelos num request só; em
# fornecedor diferente é ignorada com aviso, não silenciosamente.
same = _model_cascade(FAKE["llm"], {**FAKE["llm"], "model": "openai/gpt-4.1-mini"})
assert same == ["deepseek/deepseek-v4-flash-0731", "openai/gpt-4.1-mini"], same
other = _model_cascade(
    FAKE["llm"], {**FAKE["llm"], "base_url": "https://api.openai.com/v1", "model": "gpt-4.1"}
)
assert other is None, other
assert _model_cascade(FAKE["llm"], None) is None

# O array `models` é extensão do OpenRouter. Mandá-lo para a OpenAI devolve
# `400 Unrecognized request argument supplied: models` — e o bot fala só a
# saudação, que é a única frase que não passa pelo modelo. Aconteceu numa
# chamada real ao mover o primário para a OpenAI direto mantendo a reserva
# "igual ao primário", que até então sempre significara OpenRouter.
direto = {**FAKE["llm"], "base_url": "https://api.openai.com/v1", "model": "gpt-4.1-mini"}
assert _model_cascade(direto, {**direto, "model": "gpt-4.1"}) is None
assert _llm_extras(direto, {**direto, "model": "gpt-4.1"}) == {}
print("llm fallback:", same, "· fora do OpenRouter: recusado")

# O Pipecat repassa `extra` como kwargs do SDK da OpenAI. Mandar `models` direto
# ali derrubou TODA chamada com "unexpected keyword argument" — e nada nesta
# camada percebeu, porque só quebra no request. Conferir contra a assinatura do
# SDK pega isso sem rede.
import inspect as _inspect

from openai.resources.chat.completions import AsyncCompletions

accepted = set(_inspect.signature(AsyncCompletions.create).parameters)
extras = _llm_extras(FAKE["llm"], {**FAKE["llm"], "model": "openai/gpt-4.1-mini"})
rejected = set(extras) - accepted
assert not rejected, f"the OpenAI SDK would refuse these kwargs: {rejected}"
assert extras["extra_body"]["models"] == same, extras
print("llm extras aceitos pelo SDK:", list(extras))
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

from pipecat.turns.user_stop.speech_timeout_user_turn_stop_strategy import (
    SpeechTimeoutUserTurnStopStrategy,
)
from pipecat.turns.user_turn_strategies import UserTurnStrategies

from app.bot import _turn_strategies

analyzer = SileroVADAnalyzer(params=VADParams(stop_secs=0.6))

# Sem espera pelo fim do raciocínio, o turno fecha só por silêncio. Se o Pipecat
# voltar a decidir isso sozinho, a chamada trava em silêncio de 5 s — foi assim
# na primeira chamada real.
plain = _turn_strategies({"endpoint_ms": 600, "wait_for_complete_turn": False})
assert [type(s).__name__ for s in plain.stop] == ["SpeechTimeoutUserTurnStopStrategy"], plain.stop

# Quem abre o turno tem de ser o VAD. Deixar o padrão do Pipecat traz junto o
# TranscriptionUserTurnStartStrategy, e com os parciais do Deepgram ligados cada
# fragmento de frase virava um turno respondido — o bot falava sem parar.
assert [type(s).__name__ for s in plain.start] == ["VADUserTurnStartStrategy"], plain.start
print("turn start:", [type(s).__name__ for s in plain.start])

# Mínimo de palavras troca quem decide que o turno começou: sem ele, qualquer
# som corta o bot.
guarded = _turn_strategies(
    {"endpoint_ms": 600, "wait_for_complete_turn": False, "interrupt_min_words": 2}
)
assert [type(s).__name__ for s in guarded.start] == ["MinWordsUserTurnStartStrategy"], guarded.start
print("interrupt guard:", [type(s).__name__ for s in guarded.start])

# Com espera, o silêncio vira só gatilho e quem fecha o turno é o modelo — é o
# que segura o bot enquanto alguém soletra um e-mail.
gated = _turn_strategies({"endpoint_ms": 600, "wait_for_complete_turn": True})
assert "LLMTurnCompletionUserTurnStopStrategy" in [type(s).__name__ for s in gated.stop], gated.stop
print("turn strategies:", [type(s).__name__ for s in gated.stop])

strategies = plain
pair = LLMContextAggregatorPair(
    LLMContext(messages=[{"role": "system", "content": "hola"}]),
    user_params=LLMUserAggregatorParams(
        vad_analyzer=analyzer,
        user_turn_strategies=strategies,
        user_turn_stop_timeout=2.0,
        user_mute_strategies=[AlwaysUserMuteStrategy()],
    ),
)
print("turn stop:", type(pair.user()).__name__, "via", type(strategies.stop[0]).__name__)
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

# Cada métrica traz o valor num formato diferente — o do TTS é um número, o do
# STT é um objeto. Somar o objeto como número passou pelo build e explodiu no
# meio de uma chamada.
from pipecat.frames.frames import MetricsFrame
from pipecat.metrics.metrics import (
    LLMTokenUsage,
    LLMUsageMetricsData,
    STTUsage,
    STTUsageMetricsData,
    TTSUsageMetricsData,
)

from app.metrics import CallMetrics, eot_wait_seconds

collected = CallMetrics()
collected.record(
    MetricsFrame(
        data=[
            LLMUsageMetricsData(
                processor="llm",
                model="openai/gpt-4.1-mini",
                value=LLMTokenUsage(prompt_tokens=5200, completion_tokens=310, total_tokens=5510),
            ),
            TTSUsageMetricsData(processor="tts", model="eleven_multilingual_v2", value=840),
            STTUsageMetricsData(
                processor="stt", model="nova-3", value=STTUsage(audio_seconds=47.3)
            ),
        ]
    )
)

import asyncio as _asyncio

from pipecat.frames.frames import (
    BotStartedSpeakingFrame,
    TranscriptionFrame,
    UserStoppedSpeakingFrame,
)
from pipecat.observers.base_observer import FramePushed
from pipecat.processors.frame_processor import FrameDirection as _Dir

# O payload do EndOfTurn do Flux, como ele chega em `TranscriptionFrame.result`.
# A última palavra acaba em 1,10 s e o Flux só fechou o turno em 1,45 s: esses
# 350 ms são espera de quem ligou e entram na latência.
FLUX_EOT = {
    "type": "TurnInfo",
    "event": "EndOfTurn",
    "audio_window_start": 0,
    "audio_window_end": 1.45,
    "transcript": "Hola, buenos dias",
    "words": [
        {"word": "Hola,", "confidence": 0.98, "start": 0.2, "end": 0.5},
        {"word": "buenos", "confidence": 0.97, "start": 0.6, "end": 0.9},
        {"word": "dias", "confidence": 0.96, "start": 0.95, "end": 1.10},
    ],
    "end_of_turn_confidence": 0.88,
}

assert abs(eot_wait_seconds(FLUX_EOT) - 0.35) < 1e-6, eot_wait_seconds(FLUX_EOT)
# Nova não manda nenhum dos dois campos, e um payload sem eles não pode explodir.
assert eot_wait_seconds({"channel": {"alternatives": []}}) == 0.0
assert eot_wait_seconds(None) == 0.0


def _push(observer, frame, direction=_Dir.DOWNSTREAM):
    _asyncio.run(
        observer.on_push_frame(
            FramePushed(
                source=None, destination=None, frame=frame, direction=direction, timestamp=0
            )
        )
    )


def _flux_turn():
    """Os quadros que a rota Flux emite num turno, na ordem real.

    `_handle_end_of_turn` empurra a transcrição final e só depois anuncia que o
    usuário parou de falar; a resposta começa no `BotStartedSpeakingFrame`.
    """
    return [
        TranscriptionFrame("Hola, buenos dias", "caller", "", None, result=FLUX_EOT, finalized=True),
        UserStoppedSpeakingFrame(),
        BotStartedSpeakingFrame(),
    ]


# A regressão que zerou a aba Voz: o observador do Pipecat cronometra a partir
# do `VADUserStoppedSpeakingFrame`, e sob Flux não existe VAD no pipeline. Este
# bloco prova que o caminho antigo não mede nada nesta sequência — sem ele, o
# teste abaixo passaria também na versão quebrada.
from pipecat.observers.user_bot_latency_observer import UserBotLatencyObserver

_pipecat_measured = []
_pipecat_observer = UserBotLatencyObserver()


@_pipecat_observer.event_handler("on_latency_measured")
async def _record(_observer, seconds):
    _pipecat_measured.append(seconds)


for _frame in _flux_turn():
    _push(_pipecat_observer, _frame)
assert not _pipecat_measured, f"o observador do Pipecat mediu sob Flux: {_pipecat_measured}"
print("UserBotLatencyObserver sob Flux: 0 medicoes (por isso ele saiu)")

for _frame in _flux_turn():
    _push(collected, _frame)
assert collected.turns == 1, collected.turns
# A espera do EOT (350 ms) mais o que o pipeline levou entre os dois quadros,
# que num teste em memória é quase nada.
assert 350 <= collected.latencies_ms[0] < 450, collected.latencies_ms

# A saudação fala sem turno antes dela e não é espera de ninguém.
_greeting = CallMetrics()
_push(_greeting, BotStartedSpeakingFrame())
assert _greeting.latencies_ms == [], _greeting.latencies_ms
print("saudacao nao vira turno:", _greeting.as_payload()["latency_median_ms"])

# `broadcast_frame` manda o mesmo evento para os dois lados, como dois quadros
# de ids diferentes: sem filtrar direção, cada turno contaria duas vezes.
_both_ways = CallMetrics()
_push(_both_ways, UserStoppedSpeakingFrame())
_push(_both_ways, UserStoppedSpeakingFrame(), _Dir.UPSTREAM)
assert _both_ways.turns == 1, f"o irmao upstream foi contado: {_both_ways.turns}"
print("turno contado uma vez com os dois sentidos no pipeline")

# Um quadro de métrica passa por vários processadores e o observador o vê em
# cada salto. Contar em toda passagem inflou 96 s de áudio para 677 s.
seen_twice = MetricsFrame(
    data=[STTUsageMetricsData(processor="stt", model="nova-3", value=STTUsage(audio_seconds=10.0))]
)
repeated = CallMetrics()
for _ in range(3):
    _push(repeated, seen_twice)
assert repeated.stt_seconds == 10.0, f"counted the same frame more than once: {repeated.stt_seconds}"
print("dedupe de metricas: 3 passagens ->", repeated.stt_seconds, "s")

payload = collected.as_payload()
assert payload["prompt_tokens"] == 5200 and payload["tts_characters"] == 840, payload
assert payload["stt_seconds"] == 47.3, payload
assert payload["turns"] == 1 and payload["latency_median_ms"] is not None, payload
print("metrics:", payload)


# A voz do bot não pode voltar como fala de quem ligou.
#
# O `deserialize` do Pipecat aceita todo evento `media`, venha da pista de
# quem ligou ou da nossa. Com as duas entrando, o Flux anunciava turno do
# usuário enquanto o bot falava, cortava a saudação em "Brands" e mandava a
# própria voz do bot ao modelo como pergunta do cliente. Uma chamada com o
# microfone mudo provou o caminho; este assert impede o retorno dele.
import base64 as _base64
import json as _json

from pipecat.frames.frames import StartFrame
from pipecat.serializers.twilio import TwilioFrameSerializer as _TFS

from app.bot import CallerAudioOnlySerializer

_ser = CallerAudioOnlySerializer(
    stream_sid="MZsmoke", call_sid="CAsmoke", params=_TFS.InputParams(auto_hang_up=False)
)
# Sem o StartFrame o serializer não sabe a taxa de amostragem e o resampler
# recusa o áudio de entrada — é o que o pipeline faz antes do primeiro quadro.
_asyncio.run(_ser.setup(StartFrame(audio_in_sample_rate=8000, audio_out_sample_rate=8000)))
_media = lambda track: _json.dumps(  # noqa: E731
    {"event": "media", "media": {"track": track, "payload": _base64.b64encode(b"\xff" * 160).decode()}}
)

assert _asyncio.run(_ser.deserialize(_media("outbound"))) is None
assert _ser.tracks_seen == {"outbound": 1}, _ser.tracks_seen

# A de quem ligou continua entrando, e sem `track` o padrão é ela.
assert _asyncio.run(_ser.deserialize(_media("inbound"))) is not None
assert _asyncio.run(_ser.deserialize(_json.dumps({"event": "media", "media": {"payload": ""}}))) is None
assert _ser.tracks_seen == {"outbound": 1, "inbound": 2}, _ser.tracks_seen
print("audio tracks:", _ser.tracks_seen, "(outbound descartada)")


# Nada chega ao transcritor antes de o bot terminar de se apresentar.
#
# O Flux alucina uma frase de estoque sobre o quase-silêncio da linha e chama
# aquilo de turno de quem ligou. Numa chamada o turno fantasma abriu 544 ms
# depois de a saudação começar, a partir de áudio capturado quando o bot ainda
# estava calado — por isso o primeiro quadro, antes de qualquer fala do bot,
# também tem de sair silenciado. E tem de voltar ao normal assim que ele cala,
# senão a chamada trava esperando um turno que não vem.
from pipecat.frames.frames import (
    BotStartedSpeakingFrame,
    BotStoppedSpeakingFrame,
    InputAudioRawFrame,
)
from pipecat.tests.utils import run_test as _run_test

from app.bot import SilenceUntilBotHasSpoken

_gate = SilenceUntilBotHasSpoken()
_loud = lambda: InputAudioRawFrame(  # noqa: E731
    audio=b"\x7f" * 320, sample_rate=8000, num_channels=1
)
_down, _ = _asyncio.run(
    _run_test(
        _gate,
        frames_to_send=[
            _loud(),
            BotStartedSpeakingFrame(),
            _loud(),
            BotStoppedSpeakingFrame(),
            _loud(),
        ],
        expected_down_frames=[
            InputAudioRawFrame,
            BotStartedSpeakingFrame,
            InputAudioRawFrame,
            BotStoppedSpeakingFrame,
            InputAudioRawFrame,
        ],
    )
)
_opening, _during, _after = _down[0], _down[2], _down[4]
assert _opening.audio == bytes(320), "áudio antes da saudação tinha de sair silenciado"
assert _during.audio == bytes(320), "áudio durante a fala do bot tinha de sair silenciado"
assert _after.audio == b"\x7f" * 320, "depois da saudação o áudio não pode ser tocado"
assert _gate.frames_silenced == 2, _gate.frames_silenced
print("echo gate: silencia antes e durante a saudação, abre depois")

print("\nSMOKE OK")
