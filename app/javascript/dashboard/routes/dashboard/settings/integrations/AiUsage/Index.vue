<script setup>
// Uso de IA da conta: o que o bot gastou com LLM (respostas, resumos da
// passagem e follow-ups) e com o Jev, e o teto mensal. O teto é do Super
// Admin; aqui ele só aparece. Com o mês no teto, o bot passa as mensagens
// novas para a equipe sem chamar a IA (Guard do n8n).
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import BarChart from 'shared/components/charts/BarChart.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();

const PERIODS = ['THIS_MONTH', 'LAST_30_DAYS', 'LAST_MONTH'];
const KINDS = ['reply', 'briefing', 'followup', 'memory'];
const NEAR_CAP = 0.8;

const period = ref('THIS_MONTH');
const usage = ref(null);
const isLoading = ref(true);

const rangeFor = key => {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  if (key === 'LAST_30_DAYS') {
    return { from: new Date(now - 30 * 86400000), to: now };
  }
  if (key === 'LAST_MONTH') {
    return {
      from: new Date(now.getFullYear(), now.getMonth() - 1, 1),
      to: startOfMonth,
    };
  }
  return { from: startOfMonth, to: now };
};

const fetchUsage = async () => {
  const { from, to } = rangeFor(period.value);
  try {
    const { data } = await BotlayerAPI.aiUsage({
      from: from.toISOString(),
      to: to.toISOString(),
    });
    usage.value = data;
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INTEGRATION_SETTINGS.AI_USAGE.ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const usd = (value, digits = 2) =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(Number(value) || 0);

// Uma resposta custa frações de centavo: com 2 casas tudo vira US$ 0,00.
const small = value => usd(value, Number(value) < 1 ? 4 : 2);

const total = computed(
  () => Number(usage.value?.llm_usd || 0) + Number(usage.value?.jev_usd || 0)
);
const perConversation = computed(() =>
  usage.value?.conversations ? total.value / usage.value.conversations : 0
);

const budget = computed(() =>
  usage.value?.budget_usd === null || usage.value?.budget_usd === undefined
    ? null
    : Number(usage.value.budget_usd)
);
const monthSpend = computed(() => Number(usage.value?.month_spend_usd || 0));
const capState = computed(() => {
  if (budget.value === null) return 'none';
  if (monthSpend.value >= budget.value) return 'reached';
  return monthSpend.value >= budget.value * NEAR_CAP ? 'near' : 'ok';
});
const CAP_CLASSES = {
  reached: 'bg-n-ruby-3 text-n-ruby-11',
  near: 'bg-n-amber-3 text-n-amber-11',
  ok: 'bg-n-teal-3 text-n-teal-11',
};

const periodOptions = computed(() =>
  PERIODS.map(key => ({
    value: key,
    label: t(`INTEGRATION_SETTINGS.AI_USAGE.PERIOD.${key}`),
  }))
);

const dayLabel = day =>
  new Intl.DateTimeFormat(undefined, { day: 'numeric', month: 'short' }).format(
    new Date(day)
  );
const chartData = computed(() => {
  const days = usage.value?.by_day || [];
  return {
    categories: days.map(d => dayLabel(d.day)),
    series: [
      {
        id: 'llm',
        label: t('INTEGRATION_SETTINGS.AI_USAGE.LLM'),
        color: 'rgb(var(--blue-9))',
        data: days.map(d => Number(d.llm_usd)),
      },
      {
        id: 'jev',
        label: t('INTEGRATION_SETTINGS.AI_USAGE.JEV'),
        color: 'rgb(var(--teal-9))',
        data: days.map(d => Number(d.jev_usd)),
      },
    ],
  };
});

const kinds = computed(() =>
  KINDS.map(kind => ({
    kind,
    ...(usage.value?.by_kind?.[kind] || { usd: 0, calls: 0 }),
  }))
);

watch(period, fetchUsage);
onMounted(fetchUsage);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('INTEGRATION_SETTINGS.AI_USAGE.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.AI_USAGE.HEADER')"
        :description="$t('INTEGRATION_SETTINGS.AI_USAGE.DESCRIPTION')"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      >
        <template #actions>
          <Select v-model="period" :options="periodOptions" class="w-48" />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div v-if="usage" class="flex flex-col w-full gap-6">
        <section
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.AI_USAGE.CAP.TITLE') }}
            </h2>
            <span
              v-if="capState !== 'none'"
              class="px-2 py-0.5 text-xs font-medium rounded-md"
              :class="CAP_CLASSES[capState]"
            >
              {{ $t(`INTEGRATION_SETTINGS.AI_USAGE.CAP.STATE.${capState}`) }}
            </span>
          </div>
          <template v-if="budget !== null">
            <p class="text-body-main text-n-slate-11">
              {{
                $t('INTEGRATION_SETTINGS.AI_USAGE.CAP.SPENT', {
                  spent: small(monthSpend),
                  cap: usd(budget),
                })
              }}
            </p>
            <progress
              :value="Math.min(monthSpend, budget)"
              :max="budget || 1"
              class="w-full h-2 overflow-hidden rounded-full appearance-none [&::-webkit-progress-bar]:bg-n-slate-3 [&::-webkit-progress-value]:bg-n-blue-9 [&::-moz-progress-bar]:bg-n-blue-9"
            />
            <p class="text-sm text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_USAGE.CAP.HELP') }}
            </p>
          </template>
          <p v-else class="text-body-main text-n-slate-11">
            {{
              $t('INTEGRATION_SETTINGS.AI_USAGE.CAP.NONE', {
                spent: small(monthSpend),
              })
            }}
          </p>
        </section>

        <section class="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <div
            v-for="tile in [
              { id: 'TOTAL', value: small(total) },
              { id: 'CALLS', value: usage.calls + usage.jev_calls },
              { id: 'CONVERSATIONS', value: usage.conversations },
              { id: 'PER_CONVERSATION', value: small(perConversation) },
            ]"
            :key="tile.id"
            class="flex flex-col gap-1 p-4 border rounded-xl border-n-weak"
          >
            <span class="text-sm text-n-slate-11">
              {{ $t(`INTEGRATION_SETTINGS.AI_USAGE.TILES.${tile.id}`) }}
            </span>
            <span class="text-heading-2 text-n-slate-12">{{ tile.value }}</span>
          </div>
        </section>

        <p v-if="usage.unpriced_calls" class="text-sm text-n-amber-11">
          {{
            $t('INTEGRATION_SETTINGS.AI_USAGE.UNPRICED', {
              count: usage.unpriced_calls,
            })
          }}
        </p>

        <section
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak"
        >
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.AI_USAGE.BY_DAY') }}
          </h2>
          <BarChart
            v-if="usage.by_day.length"
            :data="chartData"
            :aria-label="$t('INTEGRATION_SETTINGS.AI_USAGE.BY_DAY')"
            :height="240"
          />
          <p v-else class="text-sm text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.AI_USAGE.EMPTY') }}
          </p>
        </section>

        <div class="grid gap-6 lg:grid-cols-2">
          <section
            class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.AI_USAGE.BY_KIND') }}
            </h2>
            <div
              v-for="row in kinds"
              :key="row.kind"
              class="flex items-center justify-between gap-4 py-1 text-sm"
            >
              <span class="text-n-slate-12">
                {{ $t(`INTEGRATION_SETTINGS.AI_USAGE.KIND.${row.kind}`) }}
              </span>
              <span class="text-n-slate-11">
                {{
                  $t('INTEGRATION_SETTINGS.AI_USAGE.CALLS_AND_COST', {
                    calls: row.calls,
                    cost: small(row.usd),
                  })
                }}
              </span>
            </div>
            <div class="flex items-center justify-between gap-4 py-1 text-sm">
              <span class="text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.AI_USAGE.JEV') }}
              </span>
              <span class="text-n-slate-11">
                {{
                  $t('INTEGRATION_SETTINGS.AI_USAGE.CALLS_AND_COST', {
                    calls: usage.jev_calls,
                    cost: small(usage.jev_usd),
                  })
                }}
              </span>
            </div>
          </section>

          <section
            class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.AI_USAGE.BY_MODEL') }}
            </h2>
            <div
              v-for="row in usage.by_model"
              :key="row.model"
              class="flex items-center justify-between gap-4 py-1 text-sm"
            >
              <span class="truncate text-n-slate-12">{{ row.model }}</span>
              <span class="shrink-0 text-n-slate-11">
                {{
                  $t('INTEGRATION_SETTINGS.AI_USAGE.CALLS_AND_COST', {
                    calls: row.calls,
                    cost: small(row.usd),
                  })
                }}
              </span>
            </div>
            <p v-if="!usage.by_model.length" class="text-sm text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_USAGE.EMPTY') }}
            </p>
          </section>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
