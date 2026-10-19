<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useLocale } from 'shared/composables/useLocale';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';

// O funil da campanha e as pessoas da lista. O WhatsApp por QR não devolve
// "entregue" e "lida", então o funil vai de enviadas a respostas; cada taxa
// tem o próprio denominador.
const props = defineProps({
  campaign: { type: Object, required: true },
});

const STATUSES = [
  '',
  'pending',
  'sending',
  'sent',
  'replied',
  'failed',
  'opted_out',
  'excluded',
  'cancelled',
];
const POLL_INTERVAL = 10000;

const { resolvedLocale } = useLocale();

const status = ref('');
const page = ref(1);
const recipients = ref([]);
const count = ref(0);
let timer = null;

const metrics = computed(() => props.campaign.metrics);
const statusOptions = computed(() =>
  STATUSES.map(value => ({
    value,
    label: value ? `${value}` : '',
  }))
);
const tiles = computed(() => [
  ['SENT', metrics.value.sent],
  ['REPLIED', metrics.value.replied],
  ['PENDING', metrics.value.pending],
  ['FAILED', metrics.value.failed],
  ['OPTED_OUT', metrics.value.opted_out],
  ['EXCLUDED', metrics.value.excluded],
]);
const percent = value => (value === null ? '—' : `${Math.round(value * 100)}%`);
const pages = computed(() => Math.max(1, Math.ceil(count.value / 100)));
const timeLabel = stamp =>
  stamp
    ? new Intl.DateTimeFormat(resolvedLocale.value, {
        dateStyle: 'short',
        timeStyle: 'short',
      }).format(new Date(stamp * 1000))
    : '';

const fetchRecipients = async () => {
  const { data } = await OutreachAPI.recipients(props.campaign.id, {
    status: status.value || undefined,
    page: page.value,
  });
  recipients.value = data.payload;
  count.value = data.meta.count;
};

watch(status, () => {
  page.value = 1;
  fetchRecipients();
});
watch(page, fetchRecipients);
onMounted(() => {
  fetchRecipients();
  timer = setInterval(fetchRecipients, POLL_INTERVAL);
});
onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <section class="flex flex-col gap-4 p-4 rounded-xl bg-n-card">
    <h2 class="text-heading-3 text-n-slate-12">
      {{ $t('OUTREACH.RESULTS.TITLE') }}
    </h2>
    <dl class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
      <div
        v-for="[key, value] in tiles"
        :key="key"
        class="flex flex-col gap-0.5 p-3 rounded-lg bg-n-alpha-1"
      >
        <dt class="text-xs text-n-slate-11">
          {{ $t(`OUTREACH.METRICS.${key}`) }}
        </dt>
        <dd class="text-lg text-n-slate-12">{{ value }}</dd>
      </div>
    </dl>
    <p class="text-xs text-n-slate-11">
      {{
        $t('OUTREACH.RESULTS.RATES', {
          reply: percent(metrics.reply_rate),
          failure: percent(metrics.failure_rate),
        })
      }}
    </p>

    <label class="flex flex-col max-w-56 gap-1">
      <span class="text-sm text-n-slate-12">
        {{ $t('OUTREACH.RESULTS.FILTER') }}
      </span>
      <Select
        v-model="status"
        :options="
          statusOptions.map(option => ({
            value: option.value,
            label: option.value
              ? $t(`OUTREACH.RECIPIENT_STATUS.${option.value}`)
              : $t('OUTREACH.RESULTS.ALL'),
          }))
        "
      />
    </label>

    <div class="overflow-x-auto rounded-lg outline outline-1 outline-n-weak">
      <table class="min-w-full text-sm text-n-slate-12">
        <thead class="bg-n-alpha-1 text-xs">
          <tr>
            <th class="px-3 py-2 font-medium text-start">
              {{ $t('OUTREACH.RESULTS.PHONE') }}
            </th>
            <th class="px-3 py-2 font-medium text-start">
              {{ $t('OUTREACH.RESULTS.NAME') }}
            </th>
            <th class="px-3 py-2 font-medium text-start">
              {{ $t('OUTREACH.RESULTS.STATUS') }}
            </th>
            <th class="px-3 py-2 font-medium text-start">
              {{ $t('OUTREACH.RESULTS.DETAIL') }}
            </th>
            <th class="px-3 py-2 font-medium text-start">
              {{ $t('OUTREACH.RESULTS.SENT_AT') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in recipients" :key="item.id">
            <td class="px-3 py-2 border-t border-n-weak">{{ item.phone }}</td>
            <td class="px-3 py-2 border-t border-n-weak">{{ item.name }}</td>
            <td class="px-3 py-2 border-t border-n-weak">
              {{ $t(`OUTREACH.RECIPIENT_STATUS.${item.status}`) }}
            </td>
            <td
              class="px-3 py-2 text-xs border-t border-n-weak text-n-slate-11"
            >
              <template v-if="item.excluded_reason">
                {{ $t(`OUTREACH.REASON.${item.excluded_reason}`) }}
              </template>
              <template v-else>{{ item.error }}</template>
            </td>
            <td
              class="px-3 py-2 text-xs border-t border-n-weak text-n-slate-11"
            >
              {{ timeLabel(item.sent_at) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div v-if="pages > 1" class="flex items-center gap-2 text-sm">
      <Button
        xs
        slate
        faded
        icon="i-lucide-chevron-left"
        :label="$t('OUTREACH.RESULTS.PREVIOUS')"
        :disabled="page === 1"
        @click="page -= 1"
      />
      <span class="text-n-slate-11">{{ page }} / {{ pages }}</span>
      <Button
        xs
        slate
        faded
        icon="i-lucide-chevron-right"
        :label="$t('OUTREACH.RESULTS.NEXT')"
        :disabled="page === pages"
        @click="page += 1"
      />
    </div>
  </section>
</template>
