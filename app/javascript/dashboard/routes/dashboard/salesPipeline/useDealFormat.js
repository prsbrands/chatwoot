import { useLocale } from 'shared/composables/useLocale';
import { dynamicTime } from 'shared/helpers/timeHelper';

// Formatacao compartilhada entre o Kanban e o card do negocio na conversa.
export function useDealFormat() {
  const { resolvedLocale } = useLocale();

  const formatMoney = (cents, currency) => {
    if (cents === null || cents === undefined) return '';
    return new Intl.NumberFormat(resolvedLocale.value, {
      style: 'currency',
      currency: currency || 'USD',
      maximumFractionDigits: 0,
    }).format(cents / 100);
  };

  const sinceStageChange = deal => dynamicTime(deal.stage_changed_at);

  // Bloco 3c: cores do risco e da faixa do score, iguais no Kanban e no card.
  const RISK_CLASSES = {
    at_risk: 'bg-n-amber-9',
    critical: 'bg-n-ruby-9',
  };
  const BAND_CLASSES = {
    hot: 'bg-n-teal-3 text-n-teal-11',
    warm: 'bg-n-amber-3 text-n-amber-11',
    cold: 'bg-n-slate-3 text-n-slate-11',
  };
  const riskClass = deal => RISK_CLASSES[deal.insight?.risk] || '';
  const bandClass = deal => BAND_CLASSES[deal.insight?.score_band] || '';
  const isAtRisk = deal => Boolean(RISK_CLASSES[deal.insight?.risk]);
  const idleTime = deal =>
    deal.insight?.last_activity_at
      ? dynamicTime(deal.insight.last_activity_at)
      : '';

  return {
    formatMoney,
    sinceStageChange,
    riskClass,
    bandClass,
    isAtRisk,
    idleTime,
  };
}
