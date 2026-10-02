<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Criar ou editar uma tarefa. Aberta de um negócio ou contato, a tarefa nasce
// ligada a ele (open({ dealId }) / open({ contactId })); da tela Tasks, avulsa.
const emit = defineEmits(['saved']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');

const NOBODY = 0;
const dialogRef = ref(null);
const taskId = ref(null);
const links = ref({});
const title = ref('');
const notes = ref('');
const due = ref('');
const assigneeId = ref(NOBODY);
const isSaving = ref(false);

const assigneeOptions = computed(() => [
  { value: NOBODY, label: t('SALES_PIPELINE.TASKS.NOBODY') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);

// O <input type="datetime-local"> fala a hora local sem fuso: "2026-10-03T14:30".
const pad = number => String(number).padStart(2, '0');
const toLocalInput = epoch => {
  if (!epoch) return '';
  const date = new Date(epoch * 1000);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

const open = ({ task = null, dealId = null, contactId = null } = {}) => {
  taskId.value = task?.id || null;
  links.value = task ? {} : { deal_id: dealId, contact_id: contactId };
  title.value = task?.title || '';
  notes.value = task?.notes || '';
  due.value = toLocalInput(task?.due_at);
  assigneeId.value = task ? task.assignee?.id || NOBODY : currentUser.value.id;
  dialogRef.value.open();
};

const save = async () => {
  const task = {
    ...links.value,
    title: title.value.trim(),
    notes: notes.value.trim(),
    due_at: due.value ? new Date(due.value).toISOString() : null,
    assignee_id: assigneeId.value || null,
  };
  isSaving.value = true;
  try {
    const { data } = taskId.value
      ? await SalesPipelineAPI.updateTask(taskId.value, task)
      : await SalesPipelineAPI.createTask(task);
    emit('saved', data);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.response?.data?.error || t('SALES_PIPELINE.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
});

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    :title="
      taskId
        ? $t('SALES_PIPELINE.TASKS.EDIT')
        : $t('SALES_PIPELINE.TASKS.NEW')
    "
    :confirm-button-label="$t('SALES_PIPELINE.TASKS.SAVE')"
    :disable-confirm-button="!title.trim()"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <Input
        v-model="title"
        :label="$t('SALES_PIPELINE.TASKS.TITLE')"
        :placeholder="$t('SALES_PIPELINE.TASKS.TITLE_PLACEHOLDER')"
      />
      <Input
        v-model="due"
        type="datetime-local"
        :label="$t('SALES_PIPELINE.TASKS.DUE')"
      />
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('SALES_PIPELINE.TASKS.ASSIGNEE') }}
        <Select v-model="assigneeId" :options="assigneeOptions" />
      </label>
      <TextArea
        v-model="notes"
        :label="$t('SALES_PIPELINE.TASKS.NOTES')"
        :max-length="2000"
      />
    </div>
  </Dialog>
</template>
