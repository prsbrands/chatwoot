<script setup>
import { onMounted, ref, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import CasesAPI from 'dashboard/api/cases';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// Fase 3: como os casos andam no período e agora — abertos (e quantos pela
// IA), resolvidos, tempo até resolver, no prazo, ativos e atrasados — no
// total, por tipo e por responsável (Cases::Metrics).
const PERIODS = [7, 30, 90];
const COLUMNS = [
  'opened',
  'opened_by_ai',
  'resolved',
  'avg_resolution_hours',
  'on_time_rate',
  'active',
  'overdue',
];

const { accountScopedRoute } = useAccount();
const days = ref(30);
const metrics = ref(null);
const isLoading = ref(true);

const fetchMetrics = async () => {
  isLoading.value = true;
  try {
    const { data } = await CasesAPI.metrics(days.value);
    metrics.value = data;
  } finally {
    isLoading.value = false;
  }
};

const show = (column, value) => {
  if (value === null || value === undefined) return '—';
  if (column === 'on_time_rate') return `${Math.round(value * 100)}%`;
  if (column === 'avg_resolution_hours') return `${value} h`;
  return value;
};

watch(days, fetchMetrics);
onMounted(fetchMetrics);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <router-link
        :to="accountScopedRoute('cases_index')"
        class="flex items-center gap-1 text-xs text-n-slate-11 hover:underline w-fit"
      >
        <span class="i-lucide-arrow-left size-3" />
        {{ $t('CASES.BACK') }}
      </router-link>
      <h1 class="text-heading-2 text-n-slate-12">
        {{ $t('CASES.METRICS.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ $t('CASES.METRICS.DESCRIPTION') }}
      </p>
    </header>

    <div class="flex gap-2 px-6 pt-4">
      <Button
        v-for="period in PERIODS"
        :key="period"
        xs
        :slate="days !== period"
        :faded="days !== period"
        :label="$t('CASES.METRICS.DAYS', { days: period })"
        @click="days = period"
      />
    </div>

    <div v-if="isLoading" class="flex px-6 py-5"><Spinner /></div>

    <div v-else-if="metrics" class="flex flex-col gap-8 px-6 py-5">
      <div class="grid grid-cols-2 gap-3 md:grid-cols-4 xl:grid-cols-7">
        <div
          v-for="column in COLUMNS"
          :key="column"
          class="flex flex-col gap-1 px-4 py-3 rounded-xl bg-n-card outline outline-1 outline-n-container"
        >
          <span class="text-xs text-n-slate-11">
            {{ $t(`CASES.METRICS.COLUMN.${column}`) }}
          </span>
          <span
            class="text-heading-2"
            :class="
              column === 'overdue' && metrics.summary.overdue
                ? 'text-n-ruby-11'
                : 'text-n-slate-12'
            "
          >
            {{ show(column, metrics.summary[column]) }}
          </span>
        </div>
      </div>

      <section
        v-for="group in ['by_type', 'by_assignee']"
        :key="group"
        class="flex flex-col gap-2"
      >
        <h2 class="text-sm font-medium text-n-slate-12">
          {{ $t(`CASES.METRICS.${group.toUpperCase()}`) }}
        </h2>
        <p v-if="!metrics[group].length" class="m-0 text-sm text-n-slate-11">
          {{ $t('CASES.METRICS.EMPTY') }}
        </p>
        <div
          v-else
          class="overflow-x-auto rounded-xl bg-n-card outline outline-1 outline-n-container"
        >
          <table class="w-full text-sm">
            <thead>
              <tr class="text-xs text-n-slate-11">
                <th class="px-4 py-2 font-medium text-start" />
                <th
                  v-for="column in COLUMNS"
                  :key="column"
                  class="px-3 py-2 font-medium text-end whitespace-nowrap"
                >
                  {{ $t(`CASES.METRICS.COLUMN.${column}`) }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="row in metrics[group]"
                :key="row.id || 'none'"
                class="text-n-slate-12"
              >
                <td class="px-4 py-2 whitespace-nowrap">
                  <span class="flex items-center gap-2">
                    <span
                      v-if="row.color"
                      class="rounded-full size-2"
                      :style="{ backgroundColor: row.color }"
                    />
                    {{ row.name || $t('CASES.UNASSIGNED') }}
                  </span>
                </td>
                <td
                  v-for="column in COLUMNS"
                  :key="column"
                  class="px-3 py-2 text-end"
                  :class="{
                    'text-n-ruby-11': column === 'overdue' && row.overdue,
                  }"
                >
                  {{ show(column, row[column]) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
  </section>
</template>
