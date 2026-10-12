<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useLocale } from 'shared/composables/useLocale';
import {
  ACTIVE_STATUSES,
  PRIORITY_CLASSES,
  STATUS_CLASSES,
} from '../constants';

// Um caso na lista: número, tipo, título, contato, responsável, prioridade,
// situação e prazo (vermelho quando venceu). `compact` é o painel da conversa.
const props = defineProps({
  kase: { type: Object, required: true },
  compact: { type: Boolean, default: false },
});

const { accountScopedRoute } = useAccount();
const { resolvedLocale } = useLocale();

const link = computed(() =>
  accountScopedRoute('case_show', { caseId: props.kase.id })
);
// Prazo só importa enquanto o caso está ativo.
const dueLabel = computed(() => {
  if (!props.kase.due_at || !ACTIVE_STATUSES.includes(props.kase.status)) {
    return '';
  }
  return new Intl.DateTimeFormat(resolvedLocale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(props.kase.due_at * 1000));
});
</script>

<template>
  <router-link :to="link" class="flex flex-col gap-1 min-w-0 group">
    <span class="flex items-center gap-2 text-xs text-n-slate-11">
      <span
        class="rounded-full size-2 shrink-0"
        :style="{ backgroundColor: kase.type.color }"
      />
      <span class="font-medium whitespace-nowrap">{{ kase.number }}</span>
      <span class="truncate">{{ kase.type.name }}</span>
      <span
        class="px-1.5 rounded-md shrink-0"
        :class="STATUS_CLASSES[kase.status]"
      >
        {{ $t(`CASES.STATUS.${kase.status}`) }}
      </span>
    </span>
    <span class="text-sm break-words text-n-slate-12 group-hover:underline">
      {{ kase.title }}
    </span>
    <span class="flex flex-wrap gap-x-2 text-xs text-n-slate-11">
      <span v-if="!compact">{{ kase.contact.name }}</span>
      <span :class="PRIORITY_CLASSES[kase.priority]">
        {{ $t(`CASES.PRIORITY.${kase.priority}`) }}
      </span>
      <span v-if="kase.assignee">{{ kase.assignee.name }}</span>
      <span v-else>{{ $t('CASES.UNASSIGNED') }}</span>
      <span v-if="kase.paused_at">{{ $t('CASES.PAUSED') }}</span>
      <span
        v-else-if="dueLabel"
        :class="{ 'text-n-ruby-11 font-medium': kase.overdue }"
      >
        {{
          kase.overdue
            ? $t('CASES.OVERDUE_SINCE', { date: dueLabel })
            : $t('CASES.DUE_ON', { date: dueLabel })
        }}
      </span>
    </span>
  </router-link>
</template>
