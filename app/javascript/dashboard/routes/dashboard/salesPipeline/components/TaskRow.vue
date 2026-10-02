<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useLocale } from 'shared/composables/useLocale';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Button from 'dashboard/components-next/button/Button.vue';

// Uma tarefa: concluir/reabrir no círculo, prazo (vermelho se venceu), a que
// negócio ou contato ela é, e quem cuida. `compact` é o card do negócio, onde o
// negócio já está implícito.
const props = defineProps({
  task: { type: Object, required: true },
  compact: { type: Boolean, default: false },
});
const emit = defineEmits(['changed', 'edit']);

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { resolvedLocale } = useLocale();

const done = computed(() => Boolean(props.task.completed_at));
const overdue = computed(
  () => !done.value && props.task.due_at && props.task.due_at * 1000 < Date.now()
);
const dueLabel = computed(() => {
  if (!props.task.due_at) return '';
  return new Intl.DateTimeFormat(resolvedLocale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(props.task.due_at * 1000));
});

const link = computed(() => {
  const { deal, contact } = props.task;
  if (deal?.conversation_id) {
    return accountScopedRoute('inbox_conversation', {
      conversation_id: deal.conversation_id,
    });
  }
  if (contact) return accountScopedRoute('contacts_edit', { contactId: contact.id });
  return null;
});
const linkLabel = computed(() => {
  const { deal, contact } = props.task;
  if (deal) return `${deal.title} · ${deal.stage_name}`;
  return contact?.name || '';
});

const toggle = async () => {
  try {
    await SalesPipelineAPI.updateTask(props.task.id, { completed: !done.value });
    emit('changed');
  } catch (error) {
    useAlert(error.response?.data?.error || t('SALES_PIPELINE.API.ERROR'));
  }
};

const remove = async () => {
  try {
    await SalesPipelineAPI.deleteTask(props.task.id);
    emit('changed');
  } catch (error) {
    useAlert(error.response?.data?.error || t('SALES_PIPELINE.API.ERROR'));
  }
};
</script>

<template>
  <div class="flex items-start gap-3 group">
    <button
      type="button"
      class="flex items-center justify-center mt-0.5 rounded-full size-4 shrink-0 outline outline-1"
      :class="
        done
          ? 'bg-n-teal-9 outline-n-teal-9 text-white'
          : 'outline-n-slate-8 hover:outline-n-teal-9'
      "
      :title="
        done ? $t('SALES_PIPELINE.TASKS.REOPEN') : $t('SALES_PIPELINE.TASKS.COMPLETE')
      "
      @click="toggle"
    >
      <span v-if="done" class="i-lucide-check size-3" />
    </button>
    <div class="flex flex-col flex-1 min-w-0 gap-0.5">
      <span
        class="text-sm break-words"
        :class="done ? 'line-through text-n-slate-10' : 'text-n-slate-12'"
      >
        {{ task.title }}
      </span>
      <span class="flex flex-wrap gap-x-2 text-xs text-n-slate-11">
        <span v-if="dueLabel" :class="{ 'text-n-ruby-11': overdue }">
          {{ dueLabel }}
        </span>
        <span v-if="task.assignee">{{ task.assignee.name }}</span>
        <router-link
          v-if="!compact && link"
          :to="link"
          class="text-xs truncate text-n-slate-11 hover:text-n-slate-12 hover:underline"
        >
          {{ linkLabel }}
        </router-link>
      </span>
      <span v-if="task.notes && !compact" class="text-xs text-n-slate-10">
        {{ task.notes }}
      </span>
    </div>
    <div class="flex gap-1 opacity-0 group-hover:opacity-100 focus-within:opacity-100">
      <Button
        xs
        ghost
        slate
        icon="i-lucide-pencil"
        :title="$t('SALES_PIPELINE.TASKS.EDIT')"
        @click="emit('edit', task)"
      />
      <Button
        xs
        ghost
        ruby
        icon="i-lucide-trash-2"
        :title="$t('SALES_PIPELINE.TASKS.DELETE')"
        @click="remove"
      />
    </div>
  </div>
</template>
