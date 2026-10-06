<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import ContactAPI from 'dashboard/api/contacts';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { formatPrice } from '../constants';

// Nova assinatura: o cliente, o plano (item do catálogo mensal ou anual) e a
// forma de pagamento com cobrança online. O servidor copia preço, moeda e ciclo
// do plano; o link para o cliente assinar sai no detalhe.
const emit = defineEmits(['created']);
const { t } = useI18n();

const dialogRef = ref(null);
const plans = ref([]);
const methods = ref([]);
const contact = ref(null);
const contactQuery = ref('');
const contactResults = ref([]);
const form = ref({});
const isSaving = ref(false);

const planOptions = computed(() =>
  plans.value.map(plan => ({
    value: plan.id,
    label: `${plan.name} · ${t(`COMMERCE.CATALOG.PRICE_PER_${plan.billing_interval.toUpperCase()}`, { price: formatPrice(plan.price, plan.currency) })}`,
  }))
);
const methodOptions = computed(() =>
  methods.value.map(method => ({ value: method.id, label: method.name }))
);
const canSave = computed(
  () =>
    contact.value &&
    form.value.item_id &&
    form.value.payment_method_id &&
    Number(form.value.quantity) > 0
);

const open = async () => {
  contact.value = null;
  contactQuery.value = '';
  contactResults.value = [];
  form.value = { item_id: '', payment_method_id: '', quantity: '1' };
  dialogRef.value.open();
  try {
    const [{ data: items }, { data: paymentMethods }] = await Promise.all([
      CommerceAPI.items(),
      CommerceAPI.paymentMethods(),
    ]);
    plans.value = items.payload.filter(
      item => item.billing_interval !== 'one_time' && item.available
    );
    methods.value = paymentMethods.payload.filter(
      method => method.active && method.charges_subscriptions
    );
    form.value.item_id = plans.value[0]?.id || '';
    form.value.payment_method_id = methods.value[0]?.id || '';
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  }
};

let contactTimer = null;
const searchContacts = () => {
  clearTimeout(contactTimer);
  if (contactQuery.value.trim().length < 2) {
    contactResults.value = [];
    return;
  }
  contactTimer = setTimeout(async () => {
    const { data } = await ContactAPI.search(contactQuery.value.trim());
    contactResults.value = data.payload.slice(0, 8);
  }, 300);
};

const pickContact = picked => {
  contact.value = picked;
  contactQuery.value = '';
  contactResults.value = [];
};

const save = async () => {
  isSaving.value = true;
  try {
    const { data } = await CommerceAPI.createSubscription({
      ...form.value,
      contact_id: contact.value.id,
    });
    dialogRef.value.close();
    emit('created', data);
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    :title="$t('COMMERCE.SUBSCRIPTIONS.NEW')"
    :confirm-button-label="$t('COMMERCE.SUBSCRIPTIONS.CREATE')"
    :disable-confirm-button="!canSave"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ $t('COMMERCE.DOCUMENTS.CUSTOMER') }}
        </span>
        <div
          v-if="contact"
          class="flex items-center justify-between gap-2 px-3 py-2 border rounded-lg border-n-weak"
        >
          <span class="flex flex-col min-w-0">
            <span class="text-sm text-n-slate-12">{{ contact.name }}</span>
            <span class="text-xs text-n-slate-11">
              {{ contact.email || contact.phone_number }}
            </span>
          </span>
          <button
            type="button"
            class="text-xs text-n-blue-11"
            @click="contact = null"
          >
            {{ $t('COMMERCE.SUBSCRIPTIONS.CHANGE_CUSTOMER') }}
          </button>
        </div>
        <div v-else class="relative">
          <Input
            v-model="contactQuery"
            :placeholder="$t('COMMERCE.DOCUMENTS.SEARCH_CONTACT')"
            @input="searchContacts"
          />
          <div
            v-if="contactResults.length"
            class="absolute z-10 w-full mt-1 overflow-hidden border rounded-lg shadow-lg bg-n-solid-1 border-n-weak"
          >
            <button
              v-for="result in contactResults"
              :key="result.id"
              type="button"
              class="flex flex-col w-full px-3 py-2 text-start hover:bg-n-slate-2"
              @click="pickContact(result)"
            >
              <span class="text-sm text-n-slate-12">{{ result.name }}</span>
              <span class="text-xs text-n-slate-11">
                {{ result.email || result.phone_number }}
              </span>
            </button>
          </div>
        </div>
      </div>
      <p v-if="!plans.length" class="text-sm text-n-amber-11">
        {{ $t('COMMERCE.SUBSCRIPTIONS.NO_PLANS') }}
      </p>
      <label
        v-else
        class="flex flex-col gap-1 text-label-small text-n-slate-11"
      >
        {{ $t('COMMERCE.SUBSCRIPTIONS.PLAN') }}
        <Select v-model="form.item_id" :options="planOptions" />
      </label>
      <Input
        v-model="form.quantity"
        type="number"
        min="0.001"
        step="1"
        :label="$t('COMMERCE.SUBSCRIPTIONS.QUANTITY')"
      />
      <p v-if="!methods.length" class="text-sm text-n-amber-11">
        {{ $t('COMMERCE.SUBSCRIPTIONS.NO_ONLINE_METHODS') }}
      </p>
      <label
        v-else
        class="flex flex-col gap-1 text-label-small text-n-slate-11"
      >
        {{ $t('COMMERCE.SUBSCRIPTIONS.PAYMENT_METHOD') }}
        <Select v-model="form.payment_method_id" :options="methodOptions" />
        <span class="text-n-slate-10">
          {{ $t('COMMERCE.SUBSCRIPTIONS.PAYMENT_METHOD_HELP') }}
        </span>
      </label>
    </div>
  </Dialog>
</template>
