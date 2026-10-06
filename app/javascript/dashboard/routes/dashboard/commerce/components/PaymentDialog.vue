<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

// Registrar um pagamento recebido da fatura. Começa com o saldo em aberto e,
// por padrão, emite o recibo e o envia pelos canais da fatura.
const props = defineProps({
  paymentMethods: { type: Array, default: () => [] },
});
const emit = defineEmits(['saved']);
const { t } = useI18n();

const dialogRef = ref(null);
const doc = ref(null);
const amount = ref('');
const paidOn = ref('');
const methodId = ref('');
const note = ref('');
const sendReceipt = ref(true);
const isSaving = ref(false);

const methodOptions = computed(() => [
  { value: '', label: t('COMMERCE.DOCUMENTS.NO_METHOD') },
  ...props.paymentMethods.map(m => ({ value: m.id, label: m.name })),
]);

const open = document => {
  doc.value = document;
  amount.value = document.balance;
  paidOn.value = new Date().toISOString().slice(0, 10);
  methodId.value = '';
  note.value = '';
  sendReceipt.value = true;
  dialogRef.value.open();
};

const save = async () => {
  isSaving.value = true;
  try {
    const { data } = await CommerceAPI.addDocumentPayment(doc.value.id, {
      amount: amount.value,
      paid_on: paidOn.value,
      payment_method_id: methodId.value || null,
      note: note.value,
      send_receipt: sendReceipt.value,
    });
    emit('saved', data);
    dialogRef.value.close();
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
    :title="$t('COMMERCE.DOCUMENTS.ADD_PAYMENT')"
    :confirm-button-label="$t('COMMERCE.SAVE')"
    :disable-confirm-button="!(Number(amount) > 0) || !paidOn"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <Input
        v-model="amount"
        type="number"
        min="0"
        step="0.01"
        :label="$t('COMMERCE.DOCUMENTS.AMOUNT')"
      />
      <Input
        v-model="paidOn"
        type="date"
        :label="$t('COMMERCE.DOCUMENTS.PAID_ON')"
      />
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('COMMERCE.PAYMENT_METHODS.TITLE') }}
        <Select v-model="methodId" :options="methodOptions" />
      </label>
      <Input v-model="note" :label="$t('COMMERCE.DOCUMENTS.PAYMENT_NOTE')" />
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="sendReceipt" />
        {{ $t('COMMERCE.DOCUMENTS.SEND_RECEIPT') }}
      </label>
    </div>
  </Dialog>
</template>
