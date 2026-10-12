<script setup>
import { useI18n } from 'vue-i18n';
import { useLocale } from 'shared/composables/useLocale';
import { useMapGetter } from 'dashboard/composables/store';

// O histórico do caso, em frases: quem fez o quê e quando. Os ids do
// metadata viram nomes (responsável, tipo, campo) com o que a tela já tem.
const props = defineProps({
  events: { type: Array, required: true },
  types: { type: Array, default: () => [] },
  fields: { type: Array, default: () => [] },
});

const { t } = useI18n();
const { resolvedLocale } = useLocale();
const agents = useMapGetter('agents/getAgents');

const formatDate = epochOrIso => {
  if (!epochOrIso) return t('CASES.EVENTS.NONE');
  const date =
    typeof epochOrIso === 'number'
      ? new Date(epochOrIso * 1000)
      : new Date(epochOrIso);
  return new Intl.DateTimeFormat(resolvedLocale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};
const agentName = id =>
  agents.value.find(agent => agent.id === id)?.name || t('CASES.UNASSIGNED');
const typeName = id => props.types.find(type => type.id === id)?.name || '—';
const fieldLabel = key =>
  props.fields.find(field => field.key === key)?.label || key;

const describe = event => {
  const meta = event.metadata || {};
  switch (event.kind) {
    case 'status_changed':
      return t('CASES.EVENTS.status_changed', {
        to: t(`CASES.STATUS.${meta.to}`),
        outcome: meta.outcome ? ` · ${t(`CASES.OUTCOME.${meta.outcome}`)}` : '',
      });
    case 'assigned':
      return t('CASES.EVENTS.assigned', { to: agentName(meta.to) });
    case 'priority_changed':
      return t('CASES.EVENTS.priority_changed', {
        to: t(`CASES.PRIORITY.${meta.to}`),
      });
    case 'due_changed':
      return t('CASES.EVENTS.due_changed', { to: formatDate(meta.to) });
    case 'type_changed':
      return t('CASES.EVENTS.type_changed', { to: typeName(meta.to) });
    case 'field_changed':
      return t('CASES.EVENTS.field_changed', {
        fields: Object.keys(meta.fields || {})
          .map(fieldLabel)
          .join(', '),
      });
    case 'conversation_linked':
      return t('CASES.EVENTS.conversation_linked', {
        id: meta.conversation_id,
      });
    case 'team_reply':
      return t(`CASES.EVENTS.team_reply_${meta.mode}`, {
        status: t(`CASES.RELAY.STATUS.${meta.relay}`),
      });
    case 'customer_notified':
      return meta.skipped
        ? t('CASES.EVENTS.customer_not_notified', {
            reason: t(`CASES.NOTICE_SKIPPED.${meta.skipped}`),
          })
        : t(`CASES.EVENTS.customer_notified_${meta.notice}`);
    case 'created':
      return t(
        `CASES.EVENTS.created_${meta.conversation_id ? 'conversation' : 'manual'}`,
        {
          id: meta.conversation_id,
        }
      );
    default:
      return t(`CASES.EVENTS.${event.kind}`);
  }
};

const author = event => {
  if (event.kind === 'customer_replied') return t('CASES.EVENTS.BY_CUSTOMER');
  if (event.actor_kind === 'ai') return t('CASES.EVENTS.BY_AI');
  if (event.actor_kind === 'system') return t('CASES.EVENTS.BY_SYSTEM');
  return event.actor_name || t('CASES.EVENTS.BY_SYSTEM');
};
</script>

<template>
  <ol class="flex flex-col gap-3 m-0 list-none">
    <li
      v-for="event in [...events].reverse()"
      :key="event.id"
      class="flex flex-col gap-1"
    >
      <span class="text-xs text-n-slate-11">
        <span class="font-medium text-n-slate-12">{{ author(event) }}</span>
        · {{ formatDate(event.created_at) }}
      </span>
      <p
        v-if="['note', 'ai_note', 'customer_replied'].includes(event.kind)"
        class="px-3 py-2 m-0 text-sm whitespace-pre-wrap rounded-lg bg-n-amber-2 text-n-slate-12"
      >
        {{ event.body }}
      </p>
      <template v-else>
        <span class="text-sm text-n-slate-12">{{ describe(event) }}</span>
        <p
          v-if="event.body"
          class="m-0 text-sm whitespace-pre-wrap text-n-slate-11"
        >
          {{ event.body }}
        </p>
        <p
          v-if="event.kind === 'team_reply' && event.metadata.message"
          class="px-3 py-2 m-0 text-sm whitespace-pre-wrap rounded-lg bg-n-blue-2 text-n-slate-12"
        >
          {{ event.metadata.message }}
        </p>
      </template>
    </li>
  </ol>
</template>
