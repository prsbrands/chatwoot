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

  return { formatMoney, sinceStageChange };
}
