"""O que a chamada consumiu e quanto quem ligou esperou.

O Pipecat já emite tudo isso durante a conversa — o que faltava era alguém
guardando. Sem estes números, o custo por minuto só aparece na fatura, que é um
dos riscos declarados no plano desde o começo.
"""

import time

from pipecat.frames.frames import (
    BotStartedSpeakingFrame,
    MetricsFrame,
    TranscriptionFrame,
    UserStoppedSpeakingFrame,
)
from pipecat.metrics.metrics import (
    LLMUsageMetricsData,
    STTUsageMetricsData,
    TTSUsageMetricsData,
)
from pipecat.observers.base_observer import BaseObserver, FramePushed
from pipecat.processors.frame_processor import FrameDirection

# Só estes interessam. O filtro é por classe antes da deduplicação de propósito:
# numa linha de 8 kHz passam 50 quadros de áudio por segundo por processador, e
# guardar o id de todos para deduplicar encheria a memória da chamada.
TRACKED = (MetricsFrame, TranscriptionFrame, UserStoppedSpeakingFrame, BotStartedSpeakingFrame)


def eot_wait_seconds(result) -> float:
    """Quanto o Flux esperou depois da última sílaba para declarar o turno fechado.

    O `EndOfTurn` não chega no instante em que a pessoa cala: o Flux precisa de
    silêncio para a confiança passar do `eot_threshold`. Essa espera é tempo em
    que quem ligou já parou de falar e ainda não ouve nada — é latência sentida,
    e é justamente o que o limiar controla. Medir só do `EndOfTurn` em diante
    esconderia o preço de subir 0.7 para 0.8.

    Os dois campos são segundos **relativos ao início do stream**, então a
    diferença entre eles é uma duração: não depende de casar o relógio da
    Deepgram com o nosso, que é onde uma medição dessas costuma derrapar.

    Zero quando a rota é Nova: lá o payload não tem estes campos e a contagem
    começa na liberação do turno.
    """
    if not isinstance(result, dict):
        return 0.0

    words = result.get("words") or []
    window_end = result.get("audio_window_end")
    if not words or window_end is None:
        return 0.0

    last_word_end = words[-1].get("end")
    if last_word_end is None:
        return 0.0

    return max(0.0, window_end - last_word_end)


class CallMetrics(BaseObserver):
    """Soma o consumo dos três fornecedores e cronometra a espera de quem ligou."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.prompt_tokens = 0
        self.completion_tokens = 0
        self.tts_characters = 0
        self.stt_seconds = 0.0
        self.turns = 0
        self.latencies_ms: list[int] = []
        self._counted: set[int] = set()
        self._turn_ended_at: float | None = None
        self._eot_wait = 0.0

    async def on_push_frame(self, data: FramePushed) -> None:
        if not isinstance(data.frame, TRACKED):
            return

        # `broadcast_frame` manda o mesmo evento para os dois lados do pipeline,
        # como dois quadros de ids diferentes — deduplicar por id não pega esse
        # par, e cada turno seria contado duas vezes.
        if data.direction != FrameDirection.DOWNSTREAM:
            return

        # O observador vê cada quadro uma vez por salto do pipeline. Somar em
        # toda passagem multiplicava o consumo pelo tamanho do pipeline: 96 s de
        # áudio viraram 677 s numa chamada de 98 s.
        if data.frame.id in self._counted:
            return
        self._counted.add(data.frame.id)

        self.record(data.frame)

    # Separado do observador para o teste de fumaça poder alimentá-lo com
    # quadros de verdade: o formato de cada métrica difere (o do TTS é um número,
    # o do STT é um objeto) e errar isso só aparece no meio de uma chamada.
    def record(self, frame) -> None:
        if isinstance(frame, MetricsFrame):
            self._record_usage(frame)
        elif isinstance(frame, TranscriptionFrame):
            # Sai na frente do `UserStoppedSpeakingFrame` e é o único lugar onde
            # o payload cru do Flux chega até aqui.
            self._eot_wait = eot_wait_seconds(frame.result)
        elif isinstance(frame, UserStoppedSpeakingFrame):
            self.turns += 1
            self._turn_ended_at = time.time()
        elif isinstance(frame, BotStartedSpeakingFrame):
            self._close_turn()

    def _record_usage(self, frame: MetricsFrame) -> None:
        for entry in frame.data:
            if isinstance(entry, LLMUsageMetricsData):
                self.prompt_tokens += entry.value.prompt_tokens or 0
                self.completion_tokens += entry.value.completion_tokens or 0
            elif isinstance(entry, TTSUsageMetricsData):
                self.tts_characters += entry.value or 0
            elif isinstance(entry, STTUsageMetricsData):
                # Aqui `value` é um objeto, não um número — ao contrário do TTS.
                self.stt_seconds += entry.value.audio_seconds or 0

    def _close_turn(self) -> None:
        """Da última sílaba de quem ligou à primeira do bot."""
        # A saudação fala sem ninguém ter falado antes, e a espera dela é o
        # `greeting_delay_ms` configurado — entraria na conta como um turno
        # lentíssimo que ninguém esperou.
        if self._turn_ended_at is None:
            return

        waited = time.time() - self._turn_ended_at + self._eot_wait
        self.latencies_ms.append(int(waited * 1000))
        self._turn_ended_at = None
        self._eot_wait = 0.0

    def as_payload(self) -> dict:
        # Mediana em vez de média: uma resposta lenta no meio de dez rápidas
        # distorce a média e some na mediana, e o que interessa é como a chamada
        # soou na maior parte do tempo. O pior caso vai separado.
        ordered = sorted(self.latencies_ms)
        return {
            # Turnos são contados no evento, não no tamanho da lista de
            # latências: um turno sem resposta medida (o último antes de
            # desligar) continua tendo acontecido.
            "turns": self.turns,
            "prompt_tokens": self.prompt_tokens,
            "completion_tokens": self.completion_tokens,
            "tts_characters": self.tts_characters,
            "stt_seconds": round(self.stt_seconds, 1),
            "latency_median_ms": ordered[len(ordered) // 2] if ordered else None,
            "latency_worst_ms": ordered[-1] if ordered else None,
        }
