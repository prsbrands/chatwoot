<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import { useI18n } from 'vue-i18n';
import CasesAPI from 'dashboard/api/cases';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CaseDialog from '../components/CaseDialog.vue';
import CaseRow from '../components/CaseRow.vue';
import { ACTIVE_STATUSES, PRIORITIES } from '../constants';

// Os casos da conta: os ativos por prazo (atrasado primeiro), em lista ou em
// quadro por situação; resolvidos e cancelados, os mais recentes.
const VIEWS = ['list', 'board'];
const STATUS_FILTERS = ['active', 'resolved', 'canceled'];
const OWNERS = ['all', 'me', 'none'];

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const { isAdmin } = useAdmin();
const { accountScopedRoute } = useAccount();

const cases = ref([]);
const total = ref(0);
const page = ref(1);
const types = ref([]);
const view = ref('list');
const status = ref('active');
const owner = ref('all');
const typeId = ref('');
const priority = ref('');
const overdueOnly = ref(false);
const query = ref('');
const isLoading = ref(true);
const dialogRef = ref(null);

const typeOptions = computed(() => [
  { value: '', label: t('CASES.FILTERS.ALL_TYPES') },
  ...types.value.map(type => ({ value: type.id, label: type.name })),
]);
const priorityOptions = computed(() => [
  { value: '', label: t('CASES.FILTERS.ALL_PRIORITIES') },
  ...PRIORITIES.map(value => ({ value, label: t(`CASES.PRIORITY.${value}`) })),
]);
const columns = computed(() =>
  ACTIVE_STATUSES.map(id => ({
    id,
    cases: cases.value.filter(kase => kase.status === id),
  }))
);
const showBoard = computed(
  () => view.value === 'board' && status.value === 'active'
);

const params = () => ({
  status: status.value,
  assignee_id: owner.value === 'all' ? undefined : owner.value,
  type_id: typeId.value || undefined,
  priority: priority.value || undefined,
  overdue: overdueOnly.value || undefined,
  q: query.value.trim() || undefined,
  page: page.value,
});

const fetchCases = async ({ more = false } = {}) => {
  page.value = more ? page.value + 1 : 1;
  if (!more) isLoading.value = true;
  try {
    const { data } = await CasesAPI.list(params());
    cases.value = more ? [...cases.value, ...data.payload] : data.payload;
    total.value = data.meta.total;
  } finally {
    isLoading.value = false;
  }
};

let searchTimer = null;
const search = () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(fetchCases, 300);
};

const opened = kase => {
  store.dispatch('cases/fetchOverdueCount');
  router.push(accountScopedRoute('case_show', { caseId: kase.id }));
};

watch([status, owner, typeId, priority, overdueOnly], () => fetchCases());
onMounted(async () => {
  fetchCases();
  const { data } = await CasesAPI.types();
  types.value = data.payload;
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col gap-1 min-w-0">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('CASES.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('CASES.DESCRIPTION_TEXT') }}
        </p>
      </div>
      <div class="flex gap-2">
        <Button
          v-if="isAdmin"
          sm
          slate
          faded
          icon="i-lucide-settings"
          :label="$t('CASES.SETTINGS.HEADER')"
          @click="router.push(accountScopedRoute('cases_settings'))"
        />
        <Button
          sm
          icon="i-lucide-plus"
          :label="$t('CASES.NEW')"
          @click="dialogRef.open()"
        />
      </div>
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pt-4">
      <Button
        v-for="option in STATUS_FILTERS"
        :key="option"
        xs
        :slate="status !== option"
        :faded="status !== option"
        :label="$t(`CASES.FILTERS.STATUS.${option}`)"
        @click="status = option"
      />
      <span class="w-px h-4 mx-1 bg-n-weak" />
      <Button
        v-for="option in OWNERS"
        :key="option"
        xs
        :slate="owner !== option"
        :faded="owner !== option"
        :label="$t(`CASES.FILTERS.OWNER.${option}`)"
        @click="owner = option"
      />
      <span class="w-px h-4 mx-1 bg-n-weak" />
      <Button
        xs
        :ruby="overdueOnly"
        :slate="!overdueOnly"
        :faded="!overdueOnly"
        icon="i-lucide-alarm-clock"
        :label="$t('CASES.FILTERS.OVERDUE')"
        @click="overdueOnly = !overdueOnly"
      />
    </div>
    <div class="flex flex-wrap items-center gap-2 px-6 pt-3">
      <Select v-model="typeId" :options="typeOptions" />
      <Select v-model="priority" :options="priorityOptions" />
      <div class="w-64">
        <Input
          v-model="query"
          :placeholder="$t('CASES.FILTERS.SEARCH')"
          @input="search"
        />
      </div>
      <div v-if="status === 'active'" class="flex gap-1 ms-auto">
        <Button
          v-for="option in VIEWS"
          :key="option"
          xs
          :slate="view !== option"
          :faded="view !== option"
          :icon="option === 'list' ? 'i-lucide-list' : 'i-lucide-columns-3'"
          :title="$t(`CASES.VIEW.${option}`)"
          @click="view = option"
        />
      </div>
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
    </div>

    <p v-else-if="!cases.length" class="px-6 py-5 text-sm text-n-slate-11">
      {{ $t(`CASES.EMPTY.${status}`) }}
    </p>

    <div v-else-if="showBoard" class="grid gap-4 px-6 py-5 md:grid-cols-3">
      <section
        v-for="column in columns"
        :key="column.id"
        class="flex flex-col gap-2 min-w-0"
      >
        <h2 class="text-xs font-medium tracking-wide uppercase text-n-slate-11">
          {{ $t(`CASES.STATUS.${column.id}`) }} · {{ column.cases.length }}
        </h2>
        <ul class="flex flex-col gap-2 m-0 list-none">
          <li
            v-for="kase in column.cases"
            :key="kase.id"
            class="px-3 py-2 rounded-xl bg-n-card outline outline-1"
            :class="kase.overdue ? 'outline-n-ruby-6' : 'outline-n-container'"
          >
            <CaseRow :kase="kase" />
          </li>
        </ul>
      </section>
    </div>

    <div v-else class="flex flex-col gap-3 px-6 py-5">
      <ul
        class="flex flex-col m-0 list-none divide-y rounded-xl divide-n-weak bg-n-card outline outline-1 outline-n-container"
      >
        <li v-for="kase in cases" :key="kase.id" class="px-4 py-3">
          <CaseRow :kase="kase" />
        </li>
      </ul>
      <Button
        v-if="cases.length < total"
        sm
        slate
        faded
        class="self-center"
        :label="$t('CASES.LOAD_MORE', { count: total - cases.length })"
        @click="fetchCases({ more: true })"
      />
    </div>

    <CaseDialog ref="dialogRef" @saved="opened" />
  </section>
</template>
