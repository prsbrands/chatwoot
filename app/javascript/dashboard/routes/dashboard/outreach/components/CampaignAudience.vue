<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

// A lista da campanha: um arquivo (CSV, XLSX ou ODS) com o mapeamento das
// colunas, ou contatos do CRM por etiqueta e caixa. Trocar a lista apaga a
// anterior.
const props = defineProps({
  campaign: { type: Object, required: true },
});
const emit = defineEmits(['updated']);

const SOURCES = ['import', 'crm'];
const MAPPED = ['phone', 'name', 'company'];

const { t } = useI18n();
const labels = useMapGetter('labels/getLabels');
const inboxes = useMapGetter('inboxes/getInboxes');

const source = ref('import');
const file = ref(null);
const preview = ref(null);
const mapping = ref({});
const country = ref('507');
const label = ref('');
const inboxId = ref('');
const isBusy = ref(false);

const headerOptions = computed(() => [
  { value: '', label: t('OUTREACH.AUDIENCE.NO_COLUMN') },
  ...(preview.value?.headers || []).map(header => ({
    value: header,
    label: header,
  })),
]);
const labelOptions = computed(() => [
  { value: '', label: t('OUTREACH.AUDIENCE.ANY') },
  ...labels.value.map(item => ({ value: item.title, label: item.title })),
]);
const inboxOptions = computed(() => [
  { value: '', label: t('OUTREACH.AUDIENCE.ANY') },
  ...inboxes.value.map(item => ({ value: item.id, label: item.name })),
]);
const current = computed(() => props.campaign.audience);

const fail = error =>
  useAlert(
    error.response?.data?.message ||
      error.response?.data?.error ||
      t('OUTREACH.API.ERROR')
  );

const pickFile = async event => {
  [file.value] = event.target.files;
  preview.value = null;
  if (!file.value) return;
  try {
    const { data } = await OutreachAPI.previewImport(file.value);
    preview.value = data;
    mapping.value = { ...data.mapping };
  } catch (error) {
    fail(error);
  }
};

const apply = async () => {
  isBusy.value = true;
  try {
    const { data } = await OutreachAPI.audience(props.campaign.id, {
      source: source.value,
      file: source.value === 'import' ? file.value : null,
      mapping: mapping.value,
      country: country.value,
      filters:
        source.value === 'crm'
          ? { label: label.value, inbox_id: inboxId.value }
          : {},
    });
    useAlert(t('OUTREACH.AUDIENCE.APPLIED', { count: data.audience.count }));
    emit('updated', data);
  } catch (error) {
    fail(error);
  } finally {
    isBusy.value = false;
  }
};
</script>

<template>
  <section class="flex flex-col gap-4 p-4 rounded-xl bg-n-card">
    <h2 class="text-heading-3 text-n-slate-12">
      {{ $t('OUTREACH.AUDIENCE.TITLE') }}
    </h2>
    <p v-if="current.count !== undefined" class="text-sm text-n-slate-11">
      {{
        $t(`OUTREACH.AUDIENCE.CURRENT_${current.source.toUpperCase()}`, {
          count: current.count,
        })
      }}
    </p>
    <div class="flex gap-2">
      <Button
        v-for="option in SOURCES"
        :key="option"
        sm
        :slate="source !== option"
        :faded="source !== option"
        :label="$t(`OUTREACH.AUDIENCE.SOURCE.${option}`)"
        @click="source = option"
      />
    </div>

    <template v-if="source === 'import'">
      <label class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">
          {{ $t('OUTREACH.AUDIENCE.FILE') }}
        </span>
        <input
          type="file"
          accept=".csv,.xlsx,.ods"
          class="text-sm text-n-slate-11"
          @change="pickFile"
        />
        <span class="text-xs text-n-slate-11">
          {{ $t('OUTREACH.AUDIENCE.FILE_HINT') }}
        </span>
      </label>
      <template v-if="preview">
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <label v-for="key in MAPPED" :key="key" class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">
              {{ $t(`OUTREACH.AUDIENCE.COLUMN.${key}`) }}
            </span>
            <Select v-model="mapping[key]" :options="headerOptions" />
          </label>
        </div>
        <Input
          v-model="country"
          class="max-w-40"
          :label="$t('OUTREACH.AUDIENCE.COUNTRY')"
          :message="$t('OUTREACH.AUDIENCE.COUNTRY_HINT')"
        />
        <div
          class="overflow-x-auto rounded-lg outline outline-1 outline-n-weak"
        >
          <table class="min-w-full text-xs text-n-slate-12">
            <thead class="bg-n-alpha-1">
              <tr>
                <th
                  v-for="header in preview.headers"
                  :key="header"
                  class="px-3 py-1.5 text-start font-medium"
                >
                  {{ header }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in preview.sample" :key="index">
                <td
                  v-for="(cell, cellIndex) in row"
                  :key="cellIndex"
                  class="px-3 py-1.5 border-t border-n-weak"
                >
                  {{ cell }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="text-xs text-n-slate-11">
          {{ $t('OUTREACH.AUDIENCE.ROWS', { count: preview.total }) }}
        </p>
      </template>
    </template>

    <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <label class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">
          {{ $t('OUTREACH.AUDIENCE.LABEL') }}
        </span>
        <Select v-model="label" :options="labelOptions" />
      </label>
      <label class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">
          {{ $t('OUTREACH.AUDIENCE.INBOX') }}
        </span>
        <Select v-model="inboxId" :options="inboxOptions" />
      </label>
    </div>

    <div>
      <Button
        :label="$t('OUTREACH.AUDIENCE.USE')"
        :is-loading="isBusy"
        :disabled="source === 'import' ? !preview || !mapping.phone : false"
        @click="apply"
      />
    </div>
  </section>
</template>
