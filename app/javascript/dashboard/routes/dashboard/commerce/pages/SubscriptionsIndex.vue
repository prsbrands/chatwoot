<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NewSubscriptionDialog from '../components/NewSubscriptionDialog.vue';
import SubscriptionDialog from '../components/SubscriptionDialog.vue';
import {
  SUBSCRIPTION_STATUSES,
  SUBSCRIPTION_STATUS_CLASSES,
  formatPrice,
} from '../constants';

// Assinaturas da conta, com filtro por situação e busca. Nova assinatura abre
// o detalhe em seguida, para mandar o link ao cliente.
const { t } = useI18n();

const ALL = '';
const status = ref(ALL);
const search = ref('');
const subscriptions = ref([]);
const isLoading = ref(true);
const newDialog = ref(null);
const detailDialog = ref(null);

const statusOptions = computed(() => [
  { value: ALL, label: t('COMMERCE.DOCUMENTS.ALL_STATUSES') },
  ...SUBSCRIPTION_STATUSES.map(value => ({
    value,
    label: t(`COMMERCE.SUBSCRIPTIONS.STATUS.${value}`),
  })),
]);

const fetchSubscriptions = async () => {
  try {
    const { data } = await CommerceAPI.subscriptions({
      status: status.value || undefined,
      q: search.value.trim() || undefined,
    });
    subscriptions.value = data.payload;
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

let searchTimer = null;
watch(search, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(fetchSubscriptions, 300);
});
watch(status, fetchSubscriptions);

const onCreated = subscription => {
  fetchSubscriptions();
  detailDialog.value.open(subscription.id);
};

const renewal = subscription => {
  if (!subscription.current_period_end || subscription.status === 'canceled')
    return '';
  const date = new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
  }).format(new Date(subscription.current_period_end * 1000));
  return subscription.cancel_at_period_end
    ? t('COMMERCE.SUBSCRIPTIONS.ENDS_ON', { date })
    : t('COMMERCE.SUBSCRIPTIONS.RENEWS_ON', { date });
};

onMounted(fetchSubscriptions);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col min-w-0 gap-1">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('COMMERCE.SUBSCRIPTIONS.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('COMMERCE.SUBSCRIPTIONS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        sm
        icon="i-lucide-plus"
        :label="$t('COMMERCE.SUBSCRIPTIONS.NEW')"
        @click="newDialog.open()"
      />
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pt-4">
      <Select v-model="status" :options="statusOptions" class="w-44" />
      <Input
        v-model="search"
        class="w-64"
        :placeholder="$t('COMMERCE.SUBSCRIPTIONS.SEARCH')"
      />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('COMMERCE.DOCUMENTS.LOADING') }}
    </div>
    <p
      v-else-if="!subscriptions.length"
      class="px-6 py-5 text-sm text-n-slate-11"
    >
      {{ $t('COMMERCE.SUBSCRIPTIONS.EMPTY') }}
    </p>
    <div v-else class="flex flex-col px-6 py-4">
      <button
        v-for="subscription in subscriptions"
        :key="subscription.id"
        type="button"
        class="flex flex-wrap items-center gap-x-4 gap-y-1 px-3 py-3 text-start border-b border-n-weak hover:bg-n-slate-2"
        @click="detailDialog.open(subscription.id)"
      >
        <span class="w-48 font-medium truncate text-n-slate-12">
          {{ subscription.name }}
        </span>
        <span class="flex-1 min-w-0 truncate text-n-slate-12">
          {{ subscription.customer.name }}
        </span>
        <span class="w-40 text-sm text-n-slate-11">
          {{ renewal(subscription) }}
        </span>
        <span class="w-40 text-sm text-end text-n-slate-12">
          {{
            $t(
              `COMMERCE.CATALOG.PRICE_PER_${subscription.interval.toUpperCase()}`,
              { price: formatPrice(subscription.amount, subscription.currency) }
            )
          }}
        </span>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-md w-28 text-center"
          :class="SUBSCRIPTION_STATUS_CLASSES[subscription.status]"
        >
          {{ $t(`COMMERCE.SUBSCRIPTIONS.STATUS.${subscription.status}`) }}
        </span>
      </button>
    </div>
    <NewSubscriptionDialog ref="newDialog" @created="onCreated" />
    <SubscriptionDialog ref="detailDialog" @changed="fetchSubscriptions" />
  </section>
</template>
