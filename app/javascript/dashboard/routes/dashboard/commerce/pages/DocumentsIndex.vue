<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import CommerceAPI from 'dashboard/api/commerce';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { STATUS_CLASSES, formatPrice } from '../constants';

// Orçamentos e faturas da conta, com filtro por tipo, situação e busca.
const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const ALL = '';
const STATUSES = {
  quote: ['draft', 'sent', 'accepted', 'declined', 'void'],
  invoice: ['draft', 'sent', 'partially_paid', 'paid', 'void'],
};
const kind = ref('quote');
const status = ref(ALL);
const search = ref('');
const documents = ref([]);
const isLoading = ref(true);
const isCreating = ref(false);

const statusOptions = computed(() => [
  { value: ALL, label: t('COMMERCE.DOCUMENTS.ALL_STATUSES') },
  ...STATUSES[kind.value].map(value => ({
    value,
    label: t(`COMMERCE.DOCUMENTS.STATUS.${value}`),
  })),
]);

const fetchDocuments = async () => {
  try {
    const { data } = await CommerceAPI.documents({
      kind: kind.value,
      status: status.value || undefined,
      q: search.value.trim() || undefined,
    });
    documents.value = data.payload;
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

let searchTimer = null;
watch(search, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(fetchDocuments, 300);
});
watch(kind, () => {
  status.value = ALL;
  fetchDocuments();
});
watch(status, fetchDocuments);

const open = document =>
  router.push(
    accountScopedRoute('commerce_document', { documentId: document.id })
  );

const create = async () => {
  isCreating.value = true;
  try {
    const { data } = await CommerceAPI.createDocument({ kind: kind.value });
    open(data);
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const formatDate = value =>
  value
    ? new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
        new Date(`${value}T00:00:00`)
      )
    : '';

onMounted(fetchDocuments);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col min-w-0 gap-1">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('COMMERCE.DOCUMENTS.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('COMMERCE.DOCUMENTS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        sm
        icon="i-lucide-plus"
        :is-loading="isCreating"
        :label="
          kind === 'quote'
            ? $t('COMMERCE.DOCUMENTS.NEW_QUOTE')
            : $t('COMMERCE.DOCUMENTS.NEW_INVOICE')
        "
        @click="create"
      />
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pt-4">
      <div class="flex p-0.5 rounded-lg bg-n-slate-3">
        <button
          v-for="value in ['quote', 'invoice']"
          :key="value"
          type="button"
          class="px-3 py-1 text-sm rounded-md"
          :class="
            kind === value
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          @click="kind = value"
        >
          {{ $t(`COMMERCE.DOCUMENTS.KIND_PLURAL.${value}`) }}
        </button>
      </div>
      <Select v-model="status" :options="statusOptions" class="w-44" />
      <Input
        v-model="search"
        class="w-64"
        :placeholder="$t('COMMERCE.DOCUMENTS.SEARCH')"
      />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('COMMERCE.DOCUMENTS.LOADING') }}
    </div>
    <p v-else-if="!documents.length" class="px-6 py-5 text-sm text-n-slate-11">
      {{ $t('COMMERCE.DOCUMENTS.EMPTY') }}
    </p>
    <div v-else class="flex flex-col px-6 py-4">
      <button
        v-for="document in documents"
        :key="document.id"
        type="button"
        class="flex flex-wrap items-center gap-x-4 gap-y-1 px-3 py-3 text-start border-b border-n-weak hover:bg-n-slate-2"
        @click="open(document)"
      >
        <span class="w-36 font-medium text-n-slate-12">
          {{ document.number }}
        </span>
        <span class="flex-1 min-w-0 truncate text-n-slate-12">
          {{
            document.customer.name || $t('COMMERCE.DOCUMENTS.NO_CUSTOMER')
          }}
        </span>
        <span class="w-28 text-sm text-n-slate-11">
          {{ formatDate(document.issue_date) }}
        </span>
        <span class="w-32 text-sm text-end text-n-slate-12">
          {{ formatPrice(document.total, document.currency) }}
        </span>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-md w-28 text-center"
          :class="STATUS_CLASSES[document.display_status]"
        >
          {{ $t(`COMMERCE.DOCUMENTS.STATUS.${document.display_status}`) }}
        </span>
      </button>
    </div>
  </section>
</template>
