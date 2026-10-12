<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useLocale } from 'shared/composables/useLocale';
import AiEvolutionAPI from 'dashboard/api/aiEvolution';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SuggestionCard from '../components/SuggestionCard.vue';

// Evolução da IA: as propostas que a rodada diária tirou do que a equipe
// respondeu quando a IA não deu conta (Proposals) e como a IA anda semana a
// semana, com as mudanças aplicadas marcadas (Progress).
const TABS = ['proposals', 'progress'];
const STATUSES = ['pending', 'applied', 'rejected'];
const KINDS = ['', 'knowledge_add', 'knowledge_update', 'prompt_rule'];
const PROGRESS_COLUMNS = [
  'conversations',
  'handoff_rate',
  'held',
  'ai_cases',
  'applied',
];

const store = useStore();
const { resolvedLocale } = useLocale();

const tab = ref('proposals');
const status = ref('pending');
const kind = ref('');
const suggestions = ref([]);
const weeks = ref([]);
const isLoading = ref(true);

const fetchSuggestions = async () => {
  isLoading.value = true;
  try {
    const { data } = await AiEvolutionAPI.list({
      status: status.value,
      kind: kind.value || undefined,
    });
    suggestions.value = data.payload;
  } finally {
    isLoading.value = false;
  }
};

const fetchProgress = async () => {
  isLoading.value = true;
  try {
    const { data } = await AiEvolutionAPI.progress();
    weeks.value = data.payload;
  } finally {
    isLoading.value = false;
  }
};

const changed = () => {
  store.dispatch('aiEvolution/fetchPendingCount');
  fetchSuggestions();
};

const rate = week =>
  week.conversations
    ? Math.round((week.handoffs / week.conversations) * 100)
    : null;
const weekLabel = week =>
  new Intl.DateTimeFormat(resolvedLocale.value, {
    day: 'numeric',
    month: 'short',
  }).format(new Date(`${week.week}T12:00:00`));
const rows = computed(() => [...weeks.value].reverse());
const maxRate = computed(() =>
  Math.max(1, ...weeks.value.map(week => rate(week) || 0))
);

watch([status, kind], fetchSuggestions);
watch(tab, value =>
  value === 'progress' ? fetchProgress() : fetchSuggestions()
);
onMounted(fetchSuggestions);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <h1 class="text-heading-2 text-n-slate-12">
        {{ $t('AI_EVOLUTION.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ $t('AI_EVOLUTION.DESCRIPTION') }}
      </p>
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pt-4">
      <Button
        v-for="option in TABS"
        :key="option"
        sm
        :slate="tab !== option"
        :faded="tab !== option"
        :label="$t(`AI_EVOLUTION.TABS.${option}`)"
        @click="tab = option"
      />
    </div>

    <template v-if="tab === 'proposals'">
      <div class="flex flex-wrap items-center gap-2 px-6 pt-3">
        <Button
          v-for="option in STATUSES"
          :key="option"
          xs
          :slate="status !== option"
          :faded="status !== option"
          :label="$t(`AI_EVOLUTION.STATUS.${option}`)"
          @click="status = option"
        />
        <span class="w-px h-4 mx-1 bg-n-weak" />
        <Button
          v-for="option in KINDS"
          :key="option || 'all'"
          xs
          :slate="kind !== option"
          :faded="kind !== option"
          :label="
            option
              ? $t(`AI_EVOLUTION.KIND.${option}`)
              : $t('AI_EVOLUTION.ALL_KINDS')
          "
          @click="kind = option"
        />
      </div>
      <div v-if="isLoading" class="flex px-6 py-5"><Spinner /></div>
      <p
        v-else-if="!suggestions.length"
        class="px-6 py-5 text-sm text-n-slate-11"
      >
        {{ $t(`AI_EVOLUTION.EMPTY.${status}`) }}
      </p>
      <div v-else class="flex flex-col max-w-3xl gap-4 px-6 py-5">
        <SuggestionCard
          v-for="suggestion in suggestions"
          :key="suggestion.id"
          :suggestion="suggestion"
          @changed="changed"
        />
      </div>
    </template>

    <template v-else>
      <div v-if="isLoading" class="flex px-6 py-5"><Spinner /></div>
      <div v-else class="flex flex-col gap-3 px-6 py-5">
        <p class="m-0 text-sm text-n-slate-11">
          {{ $t('AI_EVOLUTION.PROGRESS.HINT') }}
        </p>
        <div
          class="overflow-x-auto rounded-xl bg-n-card outline outline-1 outline-n-container"
        >
          <table class="w-full text-sm">
            <thead>
              <tr class="text-xs text-n-slate-11">
                <th class="px-4 py-2 font-medium text-start">
                  {{ $t('AI_EVOLUTION.PROGRESS.WEEK') }}
                </th>
                <th
                  v-for="column in PROGRESS_COLUMNS"
                  :key="column"
                  class="px-3 py-2 font-medium text-end whitespace-nowrap"
                >
                  {{ $t(`AI_EVOLUTION.PROGRESS.COLUMN.${column}`) }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr v-for="week in rows" :key="week.week" class="text-n-slate-12">
                <td class="px-4 py-2 whitespace-nowrap">
                  {{ weekLabel(week) }}
                </td>
                <td class="px-3 py-2 text-end">{{ week.conversations }}</td>
                <td class="px-3 py-2">
                  <div class="flex items-center justify-end gap-2">
                    <div
                      class="w-24 h-1.5 rounded-full bg-n-alpha-2 overflow-hidden"
                    >
                      <div
                        class="h-full rounded-full bg-n-amber-9"
                        :style="{
                          width: `${((rate(week) || 0) / maxRate) * 100}%`,
                        }"
                      />
                    </div>
                    <span class="w-10 text-end">{{
                      rate(week) === null ? '—' : `${rate(week)}%`
                    }}</span>
                  </div>
                </td>
                <td class="px-3 py-2 text-end">{{ week.held }}</td>
                <td class="px-3 py-2 text-end">{{ week.ai_cases }}</td>
                <td class="px-3 py-2 text-end">
                  <span
                    v-if="week.applied"
                    class="px-1.5 rounded-md bg-n-teal-3 text-n-teal-11"
                  >
                    {{ week.applied }}
                  </span>
                  <span v-else>{{ week.applied }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </section>
</template>
