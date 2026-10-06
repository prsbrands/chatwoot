<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import CommerceAPI from 'dashboard/api/commerce';
import ContactAPI from 'dashboard/api/contacts';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import SendDocumentDialog from '../components/SendDocumentDialog.vue';
import PaymentDialog from '../components/PaymentDialog.vue';
import {
  CURRENCIES,
  DOCUMENT_LANGUAGES,
  STATUS_CLASSES,
  TAX_MODES,
  UNITS,
  documentTotals,
  formatPrice,
} from '../constants';

// Editor do orçamento ou da fatura: cliente, idioma, moeda e modo de imposto,
// linhas (do catálogo ou livres), textos e, na fatura, os pagamentos com o
// recibo de cada um. Salva a lista inteira de linhas; os totais da tela são uma
// prévia do servidor. No recibo, valor, cliente e datas vêm do pagamento: só o
// idioma e os textos mudam.
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { isAdmin } = useAdmin();
const { accountScopedRoute } = useAccount();

const CUSTOMER_FIELDS = ['name', 'tax_id_label', 'tax_id', 'email', 'phone'];
const doc = ref(null);
const form = ref({});
const lines = ref([]);
const catalog = ref([]);
const paymentMethods = ref([]);
const contactQuery = ref('');
const contactResults = ref([]);
const isSaving = ref(false);
const busy = ref('');
const confirmingDelete = ref(false);
const sendDialog = ref(null);
const paymentDialog = ref(null);

const editable = computed(() => doc.value?.editable);
// Reabrir: aceito, recusado ou anulado volta a rascunho; fatura com
// pagamento não (o servidor tem a mesma regra).
const isReceipt = computed(() => doc.value?.kind === 'receipt');
// Campos que o recibo não deixa mudar (cliente, moeda, datas, linhas).
const fieldsEditable = computed(() => editable.value && !isReceipt.value);
const canReopen = computed(
  () =>
    doc.value &&
    !isReceipt.value &&
    !doc.value.editable &&
    !doc.value.payments?.length &&
    !['paid', 'partially_paid'].includes(doc.value.status)
);
const isQuote = computed(() => doc.value?.kind === 'quote');
const totals = computed(() => documentTotals(lines.value, form.value.tax_mode));
const money = value => formatPrice(value, form.value.currency || 'USD');

// O recibo: o pagamento e a posição da fatura depois dele.
const receiptRows = computed(() => {
  const details = doc.value?.details || {};
  return [
    { label: 'PAYMENT_DATE', value: details.paid_on },
    {
      label: 'PAYMENT_METHOD',
      value: details.method || t('COMMERCE.DOCUMENTS.NO_METHOD'),
    },
    { label: 'AMOUNT_RECEIVED', value: money(doc.value?.total) },
    { label: 'INVOICE_TOTAL', value: money(details.invoice_total) },
    { label: 'PAID_TO_DATE', value: money(details.paid_to_date) },
    { label: 'BALANCE', value: money(details.balance) },
  ];
});

const optionsFor = (list, prefix) =>
  list.map(value => ({ value, label: t(`${prefix}.${value}`) }));
const languageOptions = computed(() =>
  optionsFor(DOCUMENT_LANGUAGES, 'COMMERCE.DOCUMENTS.LANGUAGE')
);
const taxModeOptions = computed(() =>
  optionsFor(TAX_MODES, 'COMMERCE.DOCUMENTS.TAX_MODE')
);
const unitOptions = computed(() => optionsFor(UNITS, 'COMMERCE.UNIT'));
const currencyOptions = CURRENCIES.map(code => ({ value: code, label: code }));
const catalogOptions = computed(() => [
  { value: '', label: t('COMMERCE.DOCUMENTS.ADD_FROM_CATALOG') },
  ...catalog.value.map(item => ({
    value: item.id,
    label: item.price
      ? `${item.name} · ${formatPrice(item.price, item.currency)}`
      : `${item.name} · ${t('COMMERCE.CATALOG.ON_QUOTE')}`,
  })),
]);
const pickedCatalogItem = ref('');

const load = data => {
  doc.value = data;
  form.value = {
    language: data.language,
    currency: data.currency,
    tax_mode: data.tax_mode,
    issue_date: data.issue_date,
    due_date: data.due_date || '',
    notes: data.notes || '',
    terms: data.terms || '',
    footer: data.footer || '',
    contact_id: data.contact_id,
    customer: { address: '', ...data.customer },
  };
  lines.value = (data.items || []).map(line => ({ ...line }));
};

const fetchDocument = async () => {
  const { data } = await CommerceAPI.document(route.params.documentId);
  load(data);
};

// Do orçamento para a fatura a rota muda só o id: o Vue reaproveita esta tela,
// então o documento é lido de novo (senão a tela seguia mostrando o orçamento).
watch(
  () => route.params.documentId,
  id => {
    if (id) fetchDocument();
  }
);

const payload = () => ({
  ...form.value,
  due_date: form.value.due_date || null,
  items: lines.value.map(line => ({
    item_id: line.item_id || null,
    name: line.name,
    description: line.description,
    quantity: line.quantity,
    unit: line.unit,
    unit_price: line.unit_price === '' ? null : line.unit_price,
    discount_percent: line.discount_percent || 0,
    tax_rate: line.tax_rate || 0,
  })),
});

const save = async () => {
  isSaving.value = true;
  try {
    const { data } = await CommerceAPI.updateDocument(doc.value.id, payload());
    load(data);
    useAlert(t('COMMERCE.DOCUMENTS.SAVED'));
    return true;
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
    return false;
  } finally {
    isSaving.value = false;
  }
};

// Ações do servidor; num documento editável, salva antes para o PDF e o envio
// saírem com o que está na tela.
const run = async (action, { saveFirst = false } = {}) => {
  if (saveFirst && editable.value && !(await save())) return;
  busy.value = action;
  try {
    const { data } = await CommerceAPI.documentAction(doc.value.id, action);
    if (action === 'to_invoice') {
      router.push(
        accountScopedRoute('commerce_document', { documentId: data.id })
      );
      return;
    }
    load(data);
    if (action === 'pdf' && data.pdfs.length) {
      window.open(data.pdfs[0].url, '_blank', 'noopener');
    }
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    busy.value = '';
  }
};

const openSend = async () => {
  if (editable.value && !(await save())) return;
  sendDialog.value.open(doc.value);
};

const removeDocument = async () => {
  if (!confirmingDelete.value) {
    confirmingDelete.value = true;
    return;
  }
  await CommerceAPI.deleteDocument(doc.value.id);
  router.push(accountScopedRoute('commerce_documents'));
};

const issueReceipt = async payment => {
  try {
    const { data } = await CommerceAPI.issueReceipt(doc.value.id, payment.id);
    load(data);
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  }
};

const openDocument = id =>
  router.push(accountScopedRoute('commerce_document', { documentId: id }));

const removePayment = async payment => {
  try {
    const { data } = await CommerceAPI.removeDocumentPayment(
      doc.value.id,
      payment.id
    );
    load(data);
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  }
};

// --- linhas -------------------------------------------------------------
const addLine = (item = null) =>
  lines.value.push({
    item_id: item?.id || null,
    name: item?.name || '',
    description: item?.description || '',
    quantity: '1',
    unit: item?.unit || 'unit',
    unit_price: item?.price ?? '',
    discount_percent: '0',
    tax_rate: '0',
  });

const addFromCatalog = id => {
  const item = catalog.value.find(entry => entry.id === id);
  if (item) addLine(item);
  pickedCatalogItem.value = '';
};

const lineTotal = line => documentTotals([line], form.value.tax_mode).total;

// --- cliente ------------------------------------------------------------
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

const pickContact = contact => {
  const extra = contact.additional_attributes || {};
  form.value.contact_id = contact.id;
  form.value.customer = {
    name: contact.name || '',
    email: contact.email || '',
    phone: contact.phone_number || '',
    tax_id_label: extra.billing_tax_id_label || '',
    tax_id: extra.billing_tax_id || '',
    address: extra.billing_address || '',
  };
  contactQuery.value = '';
  contactResults.value = [];
};

const formatDate = value =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value * 1000));

onMounted(async () => {
  const [, items, methods] = await Promise.all([
    fetchDocument(),
    CommerceAPI.items(),
    CommerceAPI.paymentMethods(),
  ]);
  catalog.value = items.data.payload.filter(item => item.available);
  paymentMethods.value = methods.data.payload;
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div
      v-if="!doc"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('COMMERCE.DOCUMENTS.LOADING') }}
    </div>
    <template v-else>
      <header
        class="flex flex-wrap items-center justify-between gap-3 px-6 py-4 border-b border-n-weak"
      >
        <div class="flex items-center min-w-0 gap-3">
          <router-link
            :to="accountScopedRoute('commerce_documents')"
            class="i-lucide-arrow-left size-5 text-n-slate-11"
            :aria-label="$t('COMMERCE.DOCUMENTS.BACK')"
          />
          <h1 class="text-heading-2 text-n-slate-12">
            {{ $t(`COMMERCE.DOCUMENTS.KIND.${doc.kind}`) }} {{ doc.number }}
          </h1>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-md"
            :class="STATUS_CLASSES[doc.display_status]"
          >
            {{ $t(`COMMERCE.DOCUMENTS.STATUS.${doc.display_status}`) }}
          </span>
          <span
            v-if="doc.archived_at"
            class="px-2 py-0.5 text-xs font-medium rounded-md bg-n-slate-3 text-n-slate-11"
          >
            {{ $t('COMMERCE.DOCUMENTS.ARCHIVED_BADGE') }}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button
            v-if="canReopen"
            sm
            amber
            outline
            icon="i-lucide-pencil"
            :label="$t('COMMERCE.DOCUMENTS.REOPEN')"
            :is-loading="busy === 'reopen'"
            @click="run('reopen')"
          />
          <Button
            v-if="editable"
            sm
            :label="$t('COMMERCE.SAVE')"
            :is-loading="isSaving"
            @click="save"
          />
          <Button
            sm
            slate
            outline
            icon="i-lucide-file-down"
            :label="$t('COMMERCE.DOCUMENTS.GENERATE_PDF')"
            :is-loading="busy === 'pdf'"
            @click="run('pdf', { saveFirst: true })"
          />
          <Button
            v-if="doc.status !== 'void'"
            sm
            slate
            outline
            icon="i-lucide-send"
            :label="$t('COMMERCE.DOCUMENTS.SEND')"
            @click="openSend"
          />
          <a
            v-if="doc.status !== 'draft'"
            :href="doc.public_url"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Button
              sm
              slate
              ghost
              icon="i-lucide-external-link"
              :label="$t('COMMERCE.DOCUMENTS.OPEN_LINK')"
            />
          </a>
          <template v-if="isQuote && editable">
            <Button
              sm
              teal
              outline
              :label="$t('COMMERCE.DOCUMENTS.MARK_ACCEPTED')"
              @click="run('accept', { saveFirst: true })"
            />
            <Button
              sm
              ruby
              ghost
              :label="$t('COMMERCE.DOCUMENTS.MARK_DECLINED')"
              @click="run('decline')"
            />
          </template>
          <Button
            v-if="isQuote && !['void', 'declined'].includes(doc.status)"
            sm
            icon="i-lucide-receipt"
            :label="$t('COMMERCE.DOCUMENTS.TO_INVOICE')"
            :is-loading="busy === 'to_invoice'"
            @click="run('to_invoice', { saveFirst: true })"
          />
        </div>
      </header>

      <div class="flex flex-col w-full max-w-6xl gap-6 px-6 py-5">
        <div class="grid gap-6 lg:grid-cols-2">
          <section
            class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('COMMERCE.DOCUMENTS.CUSTOMER') }}
            </h2>
            <div v-if="fieldsEditable" class="relative">
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
                  v-for="contact in contactResults"
                  :key="contact.id"
                  type="button"
                  class="flex flex-col w-full px-3 py-2 text-start hover:bg-n-slate-2"
                  @click="pickContact(contact)"
                >
                  <span class="text-sm text-n-slate-12">{{
                    contact.name
                  }}</span>
                  <span class="text-xs text-n-slate-11">
                    {{ contact.email || contact.phone_number }}
                  </span>
                </button>
              </div>
            </div>
            <div class="grid gap-3 sm:grid-cols-2">
              <Input
                v-for="field in CUSTOMER_FIELDS"
                :key="field"
                v-model="form.customer[field]"
                :disabled="!fieldsEditable"
                :label="$t(`COMMERCE.DOCUMENTS.CUSTOMER_FIELDS.${field}`)"
              />
            </div>
            <TextArea
              v-model="form.customer.address"
              :disabled="!fieldsEditable"
              :label="$t('COMMERCE.DOCUMENTS.CUSTOMER_FIELDS.address')"
              :max-length="500"
            />
          </section>

          <section
            class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak"
          >
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('COMMERCE.DOCUMENTS.SETTINGS') }}
            </h2>
            <div class="grid gap-3 sm:grid-cols-2">
              <label
                class="flex flex-col gap-1 text-label-small text-n-slate-11"
              >
                {{ $t('COMMERCE.DOCUMENTS.DOCUMENT_LANGUAGE') }}
                <Select
                  v-model="form.language"
                  :options="languageOptions"
                  :disabled="!editable"
                />
              </label>
              <label
                class="flex flex-col gap-1 text-label-small text-n-slate-11"
              >
                {{ $t('COMMERCE.CATALOG.CURRENCY') }}
                <Select
                  v-model="form.currency"
                  :options="currencyOptions"
                  :disabled="!fieldsEditable"
                />
              </label>
              <label
                v-if="!isReceipt"
                class="flex flex-col gap-1 text-label-small text-n-slate-11 sm:col-span-2"
              >
                {{ $t('COMMERCE.DOCUMENTS.TAX_MODE_LABEL') }}
                <Select
                  v-model="form.tax_mode"
                  :options="taxModeOptions"
                  :disabled="!editable"
                />
              </label>
              <Input
                v-model="form.issue_date"
                type="date"
                :disabled="!fieldsEditable"
                :label="$t('COMMERCE.DOCUMENTS.ISSUE_DATE')"
              />
              <Input
                v-if="!isReceipt"
                v-model="form.due_date"
                type="date"
                :disabled="!editable"
                :label="
                  isQuote
                    ? $t('COMMERCE.DOCUMENTS.VALID_UNTIL')
                    : $t('COMMERCE.DOCUMENTS.DUE_DATE')
                "
              />
            </div>
          </section>
        </div>

        <section
          v-if="isReceipt"
          class="flex flex-col gap-2 p-4 text-sm border rounded-xl border-n-weak"
        >
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('COMMERCE.DOCUMENTS.RECEIPT_SUMMARY') }}
          </h2>
          <button
            v-if="doc.source_document_id"
            type="button"
            class="self-start text-n-blue-11 hover:underline"
            @click="openDocument(doc.source_document_id)"
          >
            {{
              $t('COMMERCE.DOCUMENTS.FOR_INVOICE', {
                number: doc.details.invoice_number,
              })
            }}
          </button>
          <div
            v-for="row in receiptRows"
            :key="row.label"
            class="flex justify-between max-w-md py-1 border-b border-n-weak"
          >
            <span class="text-n-slate-11">
              {{ $t(`COMMERCE.DOCUMENTS.${row.label}`) }}
            </span>
            <span class="text-n-slate-12">{{ row.value }}</span>
          </div>
        </section>

        <section
          v-else
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('COMMERCE.DOCUMENTS.LINES') }}
            </h2>
            <div v-if="editable" class="flex flex-wrap items-center gap-2">
              <Select
                v-model="pickedCatalogItem"
                :options="catalogOptions"
                class="w-72"
                @update:model-value="addFromCatalog"
              />
              <Button
                sm
                slate
                outline
                icon="i-lucide-plus"
                :label="$t('COMMERCE.DOCUMENTS.ADD_LINE')"
                @click="addLine()"
              />
            </div>
          </div>
          <p v-if="!lines.length" class="text-sm text-n-slate-11">
            {{ $t('COMMERCE.DOCUMENTS.NO_LINES') }}
          </p>
          <div
            v-for="(line, index) in lines"
            :key="index"
            class="grid items-end gap-2 pb-3 border-b border-n-weak grid-cols-2 md:grid-cols-12"
          >
            <div class="flex flex-col gap-1 col-span-2 md:col-span-4">
              <Input
                v-model="line.name"
                :disabled="!editable"
                :label="$t('COMMERCE.CATALOG.NAME')"
              />
              <Input
                v-model="line.description"
                :disabled="!editable"
                :placeholder="$t('COMMERCE.CATALOG.DESCRIPTION')"
              />
            </div>
            <Input
              v-model="line.quantity"
              type="number"
              min="0"
              step="0.001"
              class="md:col-span-1"
              :disabled="!editable"
              :label="$t('COMMERCE.DOCUMENTS.QUANTITY')"
            />
            <label
              class="flex flex-col gap-1 text-label-small text-n-slate-11 md:col-span-2"
            >
              {{ $t('COMMERCE.CATALOG.UNIT') }}
              <Select
                v-model="line.unit"
                :options="unitOptions"
                :disabled="!editable"
              />
            </label>
            <Input
              v-model="line.unit_price"
              type="number"
              min="0"
              step="0.01"
              class="md:col-span-2"
              :disabled="!editable"
              :label="$t('COMMERCE.DOCUMENTS.UNIT_PRICE')"
              :placeholder="$t('COMMERCE.CATALOG.ON_QUOTE')"
            />
            <Input
              v-model="line.discount_percent"
              type="number"
              min="0"
              max="100"
              step="0.01"
              class="md:col-span-1"
              :disabled="!editable"
              :label="$t('COMMERCE.DOCUMENTS.DISCOUNT')"
            />
            <Input
              v-if="form.tax_mode !== 'exempt'"
              v-model="line.tax_rate"
              type="number"
              min="0"
              max="100"
              step="0.01"
              class="md:col-span-1"
              :disabled="!editable"
              :label="$t('COMMERCE.DOCUMENTS.TAX_RATE')"
            />
            <div
              class="flex items-center justify-end gap-2 md:col-span-1"
              :class="{ 'md:col-span-2': form.tax_mode === 'exempt' }"
            >
              <span class="text-sm text-n-slate-12 whitespace-nowrap">
                {{
                  line.unit_price === '' || line.unit_price === null
                    ? '—'
                    : money(lineTotal(line))
                }}
              </span>
              <Button
                v-if="editable"
                xs
                ruby
                ghost
                icon="i-lucide-x"
                :aria-label="$t('COMMERCE.DOCUMENTS.REMOVE_LINE')"
                @click="lines.splice(index, 1)"
              />
            </div>
          </div>
          <div class="flex flex-col self-end w-full gap-1 text-sm sm:w-72">
            <div class="flex justify-between">
              <span class="text-n-slate-11">{{
                $t('COMMERCE.DOCUMENTS.SUBTOTAL')
              }}</span>
              <span>{{ money(totals.subtotal) }}</span>
            </div>
            <div v-if="totals.discount" class="flex justify-between">
              <span class="text-n-slate-11">{{
                $t('COMMERCE.DOCUMENTS.DISCOUNT_TOTAL')
              }}</span>
              <span>- {{ money(totals.discount) }}</span>
            </div>
            <div v-if="totals.tax" class="flex justify-between">
              <span class="text-n-slate-11">
                {{
                  form.tax_mode === 'inclusive'
                    ? $t('COMMERCE.DOCUMENTS.TAX_INCLUDED')
                    : $t('COMMERCE.DOCUMENTS.TAX_TOTAL')
                }}
              </span>
              <span>{{ money(totals.tax) }}</span>
            </div>
            <div
              class="flex justify-between pt-1 mt-1 font-semibold border-t border-n-weak text-n-slate-12"
            >
              <span>{{ $t('COMMERCE.DOCUMENTS.TOTAL') }}</span>
              <span>{{ money(totals.total) }}</span>
            </div>
            <template v-if="!isQuote && Number(doc.amount_paid)">
              <div class="flex justify-between">
                <span class="text-n-slate-11">{{
                  $t('COMMERCE.DOCUMENTS.PAID')
                }}</span>
                <span>{{ money(doc.amount_paid) }}</span>
              </div>
              <div class="flex justify-between font-semibold">
                <span>{{ $t('COMMERCE.DOCUMENTS.BALANCE') }}</span>
                <span>{{ money(doc.balance) }}</span>
              </div>
            </template>
          </div>
        </section>

        <section
          v-if="doc.kind === 'invoice' && doc.status !== 'draft'"
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak"
        >
          <div class="flex items-center justify-between gap-2">
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('COMMERCE.DOCUMENTS.PAYMENTS') }}
            </h2>
            <Button
              v-if="isAdmin && !['paid', 'void'].includes(doc.status)"
              sm
              icon="i-lucide-plus"
              :label="$t('COMMERCE.DOCUMENTS.ADD_PAYMENT')"
              @click="paymentDialog.open(doc)"
            />
          </div>
          <p v-if="!doc.payments.length" class="text-sm text-n-slate-11">
            {{ $t('COMMERCE.DOCUMENTS.NO_PAYMENTS') }}
          </p>
          <div
            v-for="payment in doc.payments"
            :key="payment.id"
            class="flex items-center justify-between gap-3 text-sm"
          >
            <span class="text-n-slate-12">
              {{ payment.paid_on }} ·
              {{
                paymentMethods.find(m => m.id === payment.payment_method_id)
                  ?.name || $t('COMMERCE.DOCUMENTS.NO_METHOD')
              }}
              <span
                v-if="payment.online"
                class="px-1.5 py-0.5 text-xs rounded-md bg-n-blue-3 text-n-blue-11"
              >
                {{ $t('COMMERCE.DOCUMENTS.ONLINE_PAYMENT') }}
              </span>
              <span v-if="payment.note" class="text-n-slate-11">
                · {{ payment.note }}
              </span>
            </span>
            <span class="flex items-center gap-2">
              {{ money(payment.amount) }}
              <Button
                v-if="payment.receipt_id"
                xs
                slate
                link
                icon="i-lucide-receipt-text"
                :label="payment.receipt_number"
                @click="openDocument(payment.receipt_id)"
              />
              <Button
                v-else-if="isAdmin"
                xs
                slate
                link
                :label="$t('COMMERCE.DOCUMENTS.ISSUE_RECEIPT')"
                @click="issueReceipt(payment)"
              />
              <Button
                v-if="isAdmin && !payment.online"
                xs
                ruby
                ghost
                icon="i-lucide-trash-2"
                :aria-label="$t('COMMERCE.DOCUMENTS.REMOVE_PAYMENT')"
                @click="removePayment(payment)"
              />
            </span>
          </div>
        </section>

        <section class="grid gap-3 p-4 border rounded-xl border-n-weak">
          <TextArea
            v-model="form.notes"
            :disabled="!editable"
            :label="$t('COMMERCE.DOCUMENTS.NOTES')"
            :max-length="5000"
          />
          <TextArea
            v-model="form.terms"
            :disabled="!editable"
            :label="$t('COMMERCE.COMPANY.FIELDS.default_terms')"
            :max-length="5000"
          />
          <TextArea
            v-model="form.footer"
            :disabled="!editable"
            :label="$t('COMMERCE.COMPANY.FIELDS.footer')"
            :max-length="1000"
          />
        </section>

        <section
          class="flex flex-col gap-2 p-4 border rounded-xl border-n-weak"
        >
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('COMMERCE.DOCUMENTS.ARCHIVE') }}
          </h2>
          <p v-if="!doc.pdfs.length" class="text-sm text-n-slate-11">
            {{ $t('COMMERCE.DOCUMENTS.NO_PDFS') }}
          </p>
          <a
            v-for="pdf in doc.pdfs"
            :key="pdf.id"
            :href="pdf.url"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center gap-2 text-sm text-n-blue-11 hover:underline"
          >
            <span class="i-lucide-file-text size-4" />
            {{
              $t('COMMERCE.DOCUMENTS.PDF_FILE', {
                number: doc.number,
                date: formatDate(pdf.created_at),
              })
            }}
          </a>
        </section>

        <div class="flex justify-end gap-3">
          <Button
            sm
            slate
            link
            :icon="
              doc.archived_at ? 'i-lucide-archive-restore' : 'i-lucide-archive'
            "
            :label="
              doc.archived_at
                ? $t('COMMERCE.DOCUMENTS.UNARCHIVE')
                : $t('COMMERCE.DOCUMENTS.ARCHIVE_ACTION')
            "
            :is-loading="busy === 'archive' || busy === 'unarchive'"
            @click="run(doc.archived_at ? 'unarchive' : 'archive')"
          />
          <Button
            v-if="
              isAdmin &&
              !isReceipt &&
              doc.status !== 'void' &&
              !doc.payments?.length
            "
            sm
            slate
            link
            :label="$t('COMMERCE.DOCUMENTS.VOID')"
            @click="run('void')"
          />
          <Button
            v-if="doc.status === 'draft' && !isReceipt"
            sm
            ruby
            link
            icon="i-lucide-trash-2"
            :label="
              confirmingDelete
                ? $t('COMMERCE.CATALOG.DELETE_CONFIRM')
                : $t('COMMERCE.DOCUMENTS.DELETE')
            "
            @click="removeDocument"
          />
        </div>
      </div>

      <SendDocumentDialog ref="sendDialog" @sent="load" />
      <PaymentDialog
        ref="paymentDialog"
        :payment-methods="paymentMethods"
        @saved="load"
      />
    </template>
  </section>
</template>
