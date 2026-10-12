<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// Um campo próprio do tipo de caso, no formato que a API espera: número como
// número, data "AAAA-MM-DD", sim/não como booleano e vazio como null.
const props = defineProps({
  field: { type: Object, required: true },
});
const value = defineModel({ type: [String, Number, Boolean], default: null });

const { t } = useI18n();

const label = computed(() =>
  props.field.required ? `${props.field.label} *` : props.field.label
);
const selectOptions = computed(() => [
  { value: '', label: t('CASES.FIELDS.EMPTY') },
  ...props.field.options.map(option => ({ value: option, label: option })),
]);

const text = computed({
  get: () => (value.value === null ? '' : String(value.value)),
  set: input => {
    if (input === '') value.value = null;
    else if (props.field.type === 'number') {
      const number = Number(input);
      value.value = Number.isNaN(number) ? null : number;
    } else value.value = input;
  },
});
const flag = computed({
  get: () => value.value === true,
  set: checked => {
    value.value = checked;
  },
});
</script>

<template>
  <label
    v-if="field.type === 'select'"
    class="flex flex-col gap-1 text-label-small text-n-slate-11"
  >
    {{ label }}
    <Select v-model="text" :options="selectOptions" />
  </label>
  <label
    v-else-if="field.type === 'boolean'"
    class="flex items-center justify-between gap-3 text-label-small text-n-slate-11"
  >
    {{ label }}
    <Switch v-model="flag" />
  </label>
  <Input
    v-else
    v-model="text"
    :type="{ number: 'number', date: 'date' }[field.type] || 'text'"
    :label="label"
  />
</template>
