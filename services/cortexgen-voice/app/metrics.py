"""O que a chamada consumiu e quanto quem ligou esperou.

O Pipecat já emite tudo isso durante a conversa — o que faltava era alguém
guardando. Sem estes números, o custo por minuto só aparece na fatura, que é um
dos riscos declarados no plano desde o começo.
"""

from pipecat.frames.frames import MetricsFrame
from pipecat.metrics.metrics import (
    LLMUsageMetricsData,
    STTUsageMetricsData,
    TTSUsageMetricsData,
)
from pipecat.observers.base_observer import BaseObserver, FramePushed


class CallMetrics(BaseObserver):
    """Soma o consumo dos três fornecedores ao longo da chamada."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.prompt_tokens = 0
        self.completion_tokens = 0
        self.tts_characters = 0
        self.stt_seconds = 0.0
        self.latencies_ms: list[int] = []
        self._counted: set[int] = set()

    async def on_push_frame(self, data: FramePushed) -> None:
        if not isinstance(data.frame, MetricsFrame):
            return

        # O observador vê cada quadro uma vez por salto do pipeline, e um quadro
        # de métrica atravessa vários. Somar em toda passagem multiplicava o
        # consumo pelo tamanho do pipeline: 96 s de áudio viraram 677 s numa
        # chamada de 98 s.
        if data.frame.id in self._counted:
            return
        self._counted.add(data.frame.id)

        self.record(data.frame)

    # Separado do observador para o teste de fumaça poder alimentá-lo com
    # métricas de verdade: o formato de cada uma difere (o do TTS é um número, o
    # do STT é um objeto) e errar isso só aparece no meio de uma chamada.
    def record(self, frame: MetricsFrame) -> None:
        for entry in frame.data:
            if isinstance(entry, LLMUsageMetricsData):
                self.prompt_tokens += entry.value.prompt_tokens or 0
                self.completion_tokens += entry.value.completion_tokens or 0
            elif isinstance(entry, TTSUsageMetricsData):
                self.tts_characters += entry.value or 0
            elif isinstance(entry, STTUsageMetricsData):
                # Aqui `value` é um objeto, não um número — ao contrário do TTS.
                self.stt_seconds += entry.value.audio_seconds or 0

    def record_latency(self, seconds: float) -> None:
        """Do fim da fala de quem ligou à primeira sílaba do bot."""
        self.latencies_ms.append(int(seconds * 1000))

    def as_payload(self) -> dict:
        # Mediana em vez de média: uma resposta lenta no meio de dez rápidas
        # distorce a média e some na mediana, e o que interessa é como a chamada
        # soou na maior parte do tempo. O pior caso vai separado.
        ordered = sorted(self.latencies_ms)
        return {
            "turns": len(ordered),
            "prompt_tokens": self.prompt_tokens,
            "completion_tokens": self.completion_tokens,
            "tts_characters": self.tts_characters,
            "stt_seconds": round(self.stt_seconds, 1),
            "latency_median_ms": ordered[len(ordered) // 2] if ordered else None,
            "latency_worst_ms": ordered[-1] if ordered else None,
        }
