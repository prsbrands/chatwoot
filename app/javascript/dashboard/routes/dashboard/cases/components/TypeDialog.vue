<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CasesAPI from 'dashboard/api/cases';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { FIELD_TYPES, PRIORITIES, TYPE_COLORS, fieldKey } from '../constants';

// Criar ou editar um tipo de caso: nome, cor, prazo, padrões e os campos
// próprios do negócio. A chave do campo nasce do rótulo e não muda depois
// (renomear muda só o rótulo; os casos guardam o valor pela chave).
const emit = defineEmits(['saved']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

const NOBODY = 0;
const dialogRef = ref(null);
const typeId = ref(null);
const form = ref({});
const fields = ref([]);
const isSaving = ref(false);

const priorityOptions = computed(() =>
  PRIORITIES.map(value => ({ value, label: t(`CASES.PRIORITY.${value}`) }))
);
const assigneeOptions = computed(() => [
  { value: NOBODY, label: t('CASES.UNASSIGNED') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const fieldTypeOptions = computed(() =>
  FIELD_TYPES.map(value => ({ value, label: t(`CASES.FIELD_TYPES.${value}`) }))
);
const canSave = computed(
  () =>
    form.value.name?.trim() &&
    fields.value.every(
      field =>
        field.label.trim() &&
        (field.type !== 'select' || field.optionsText.trim())
    )
);

const open = (type = null) => {
  typeId.value = type?.id || null;
  form.value = {
    name: type?.name || '',
    color: type?.color || TYPE_COLORS[0],
    sla_hours: type?.sla_hours ? String(type.sla_hours) : '',
    default_priority: type?.default_priority || 'normal',
    default_assignee_id: type?.default_assignee_id || NOBODY,
    active: type ? type.active : true,
  };
  fields.value = (type?.fields || []).map(field => ({
    ...field,
    isNew: false,
    required: Boolean(field.required),
    optionsText: (field.options || []).join(', '),
  }));
  dialogRef.value.open();
};

const addField = () =>
  fields.value.push({
    key: '',
    label: '',
    type: 'text',
    required: false,
    optionsText: '',
    isNew: true,
  });
const removeField = index => fields.value.splice(index, 1);

// Chave única entre os campos: "pedido", "pedido_2"...
const uniqueKey = (label, taken) => {
  const base = fieldKey(label);
  let key = base;
  let suffix = 2;
  while (taken.has(key)) {
    key = `${base.slice(0, 37)}_${suffix}`;
    suffix += 1;
  }
  taken.add(key);
  return key;
};

const payloadFields = () => {
  const taken = new Set(
    fields.value.filter(field => !field.isNew).map(field => field.key)
  );
  return fields.value.map(field => ({
    key: field.isNew ? uniqueKey(field.label, taken) : field.key,
    label: field.label.trim(),
    type: field.type,
    required: field.required,
    ...(field.type === 'select'
      ? {
          options: field.optionsText
            .split(',')
            .map(o => o.trim())
            .filter(Boolean),
        }
      : {}),
  }));
};

const save = async () => {
  const payload = {
    ...form.value,
    name: form.value.name.trim(),
    sla_hours: form.value.sla_hours ? Number(form.value.sla_hours) : null,
    default_assignee_id: form.value.default_assignee_id || null,
    fields: payloadFields(),
  };
  isSaving.value = true;
  try {
    const { data } = typeId.value
      ? await CasesAPI.updateType(typeId.value, payload)
      : await CasesAPI.createType(payload);
    emit('saved', data);
    dialogRef.value.close();
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('CASES.API.ERROR')
    );
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
    width="2xl"
    :title="
      typeId ? $t('CASES.SETTINGS.EDIT_TYPE') : $t('CASES.SETTINGS.NEW_TYPE')
    "
    :confirm-button-label="$t('CASES.SAVE')"
    :disable-confirm-button="!canSave"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-4">
      <Input v-model="form.name" :label="$t('CASES.SETTINGS.TYPE_NAME')" />
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ $t('CASES.SETTINGS.COLOR') }}
        </span>
        <div class="flex gap-2">
          <button
            v-for="color in TYPE_COLORS"
            :key="color"
            type="button"
            class="rounded-full size-6 outline-offset-2"
            :class="
              form.color === color ? 'outline outline-2 outline-n-slate-12' : ''
            "
            :style="{ backgroundColor: color }"
            :title="color"
            @click="form.color = color"
          />
        </div>
      </div>
      <div class="grid grid-cols-3 gap-3">
        <Input
          v-model="form.sla_hours"
          type="number"
          min="1"
          :label="$t('CASES.SETTINGS.SLA_HOURS')"
          :placeholder="$t('CASES.SETTINGS.NO_SLA')"
        />
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('CASES.SETTINGS.DEFAULT_PRIORITY') }}
          <Select v-model="form.default_priority" :options="priorityOptions" />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('CASES.SETTINGS.DEFAULT_ASSIGNEE') }}
          <Select
            v-model="form.default_assignee_id"
            :options="assigneeOptions"
          />
        </label>
      </div>
      <label
        class="flex items-center justify-between gap-3 text-label-small text-n-slate-11"
      >
        {{ $t('CASES.SETTINGS.ACTIVE') }}
        <Switch v-model="form.active" />
      </label>

      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CASES.SETTINGS.FIELDS') }}
        </span>
        <p class="m-0 text-xs text-n-slate-11">
          {{ $t('CASES.SETTINGS.FIELDS_HINT') }}
        </p>
        <div
          v-for="(field, index) in fields"
          :key="field.key || `new-${index}`"
          class="flex flex-col gap-2 p-3 rounded-lg outline outline-1 outline-n-weak"
        >
          <div class="flex items-end gap-2">
            <div class="flex-1">
              <Input
                v-model="field.label"
                :label="$t('CASES.SETTINGS.FIELD_LABEL')"
              />
            </div>
            <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
              {{ $t('CASES.SETTINGS.FIELD_TYPE') }}
              <Select
                v-model="field.type"
                :options="fieldTypeOptions"
                :disabled="!field.isNew"
              />
            </label>
            <Button
              sm
              ghost
              ruby
              icon="i-lucide-trash-2"
              :title="$t('CASES.SETTINGS.REMOVE_FIELD')"
              @click="removeField(index)"
            />
          </div>
          <Input
            v-if="field.type === 'select'"
            v-model="field.optionsText"
            :label="$t('CASES.SETTINGS.FIELD_OPTIONS')"
            :placeholder="$t('CASES.SETTINGS.FIELD_OPTIONS_PLACEHOLDER')"
          />
          <label class="flex items-center gap-2 text-sm text-n-slate-12">
            <Checkbox v-model="field.required" />
            {{ $t('CASES.SETTINGS.FIELD_REQUIRED') }}
          </label>
        </div>
        <Button
          sm
          slate
          faded
          icon="i-lucide-plus"
          class="self-start"
          :label="$t('CASES.SETTINGS.ADD_FIELD')"
          @click="addField"
        />
      </div>
    </div>
  </Dialog>
</template>
