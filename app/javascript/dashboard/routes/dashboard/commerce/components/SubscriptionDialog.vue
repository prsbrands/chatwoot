<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import CommerceAPI from 'dashboard/api/commerce';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import ConversationPicker from './ConversationPicker.vue';
import {
  STATUS_CLASSES,
  SUBSCRIPTION_STATUS_CLASSES,
  formatPrice,
} from '../constants';

// Detalhe da assinatura: o link para o cliente assinar (copiar ou mandar pela
// conversa), a situação e o período, as faturas de cada ciclo com o recibo, e
// o cancelamento (admin), no fim do período ou na hora.
const emit = defineEmits(['changed']);
const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { isAdmin } = useAdmin();

const dialogRef = ref(null);
const pickerRef = ref(null);
const subscription = ref(null);
const conversationId = ref('');
const isSending = ref(false);
const isCanceling = ref(false);
// Cancelar pede um segundo clique no mesmo botão: o primeiro só arma.
const confirming = ref(null);

const isOpen = computed(
  () => subscription.value && subscription.value.status !== 'canceled'
);

const formatDate = timestamp =>
  timestamp
    ? new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
        new Date(timestamp * 1000)
      )
    : '';

const open = async id => {
  subscription.value = null;
  confirming.value = null;
  dialogRef.value.open();
  try {
    const { data } = await CommerceAPI.subscription(id);
    subscription.value = data;
    await nextTick();
    if (data.status === 'pending') {
      await pickerRef.value?.load(data.contact_id, data.conversation_id);
    }
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  }
};

const update = data => {
  subscription.value = { ...subscription.value, ...data };
  emit('changed');
};

const copyLink = async () => {
  await copyTextToClipboard(subscription.value.public_url);
  useAlert(t('COMMERCE.SUBSCRIPTIONS.LINK_COPIED'));
};

const send = async () => {
  isSending.value = true;
  try {
    const { data } = await CommerceAPI.deliverSubscription(
      subscription.value.id,
      { conversation_id: conversationId.value }
    );
    update(data);
    useAlert(t('COMMERCE.DOCUMENTS.SENT_OK'));
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isSending.value = false;
  }
};

const cancel = async atPeriodEnd => {
  if (confirming.value !== atPeriodEnd) {
    confirming.value = atPeriodEnd;
    return;
  }
  confirming.value = null;
  isCanceling.value = true;
  try {
    const { data } = await CommerceAPI.cancelSubscription(
      subscription.value.id,
      atPeriodEnd
    );
    update(data);
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isCanceling.value = false;
  }
};

const openInvoice = id => {
  dialogRef.value.close();
  router.push(accountScopedRoute('commerce_document', { documentId: id }));
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    width="2xl"
    :title="subscription?.name || $t('COMMERCE.SUBSCRIPTIONS.HEADER')"
    :show-confirm-button="false"
    :cancel-button-label="$t('COMMERCE.CLOSE')"
  >
    <div v-if="subscription" class="flex flex-col gap-4">
      <div class="flex flex-wrap items-center gap-2">
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-md"
          :class="SUBSCRIPTION_STATUS_CLASSES[subscription.status]"
        >
          {{ $t(`COMMERCE.SUBSCRIPTIONS.STATUS.${subscription.status}`) }}
        </span>
        <span class="text-sm text-n-slate-12">
          {{ subscription.customer.name }} ·
          {{
            $t(
              `COMMERCE.CATALOG.PRICE_PER_${subscription.interval.toUpperCase()}`,
              { price: formatPrice(subscription.amount, subscription.currency) }
            )
          }}
          · {{ subscription.payment_method_name }}
        </span>
      </div>
      <p
        v-if="subscription.current_period_end && isOpen"
        class="text-sm text-n-slate-11"
      >
        {{
          subscription.cancel_at_period_end
            ? $t('COMMERCE.SUBSCRIPTIONS.ENDS_ON', {
                date: formatDate(subscription.current_period_end),
              })
            : $t('COMMERCE.SUBSCRIPTIONS.RENEWS_ON', {
                date: formatDate(subscription.current_period_end),
              })
        }}
      </p>

      <section
        v-if="subscription.status === 'pending'"
        class="flex flex-col gap-3 p-3 border rounded-lg border-n-weak"
      >
        <p class="text-sm text-n-slate-11">
          {{ $t('COMMERCE.SUBSCRIPTIONS.LINK_HELP') }}
        </p>
        <div class="flex items-center gap-2">
          <span class="flex-1 min-w-0 text-sm truncate text-n-slate-12">
            {{ subscription.public_url }}
          </span>
          <Button
            sm
            slate
            outline
            icon="i-lucide-copy"
            :label="$t('COMMERCE.SUBSCRIPTIONS.COPY_LINK')"
            @click="copyLink"
          />
        </div>
        <ConversationPicker ref="pickerRef" v-model="conversationId" />
        <Button
          sm
          class="self-start"
          icon="i-lucide-send"
          :label="$t('COMMERCE.SUBSCRIPTIONS.SEND_LINK')"
          :disabled="!conversationId"
          :is-loading="isSending"
          @click="send"
        />
      </section>

      <section class="flex flex-col gap-2">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ $t('COMMERCE.SUBSCRIPTIONS.INVOICES') }}
        </h4>
        <p
          v-if="!subscription.invoices?.length"
          class="text-sm text-n-slate-11"
        >
          {{ $t('COMMERCE.SUBSCRIPTIONS.NO_INVOICES') }}
        </p>
        <button
          v-for="invoice in subscription.invoices"
          :key="invoice.id"
          type="button"
          class="flex flex-wrap items-center gap-x-4 gap-y-1 px-3 py-2 text-start border rounded-lg border-n-weak hover:bg-n-slate-2"
          @click="openInvoice(invoice.id)"
        >
          <span class="w-36 text-sm font-medium text-n-slate-12">
            {{ invoice.number }}
          </span>
          <span class="flex-1 text-sm text-n-slate-11">
            {{ invoice.period_start }} – {{ invoice.period_end }}
            <template v-if="invoice.receipts.length">
              · {{ invoice.receipts.map(r => r.number).join(', ') }}
            </template>
          </span>
          <span class="text-sm text-n-slate-12">
            {{ formatPrice(invoice.total, subscription.currency) }}
          </span>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-md"
            :class="STATUS_CLASSES[invoice.status]"
          >
            {{ $t(`COMMERCE.DOCUMENTS.STATUS.${invoice.status}`) }}
          </span>
        </button>
      </section>

      <div
        v-if="isAdmin && isOpen"
        class="flex flex-wrap justify-end gap-2 pt-2 border-t border-n-weak"
      >
        <Button
          v-if="
            subscription.status !== 'pending' &&
            !subscription.cancel_at_period_end
          "
          sm
          slate
          outline
          :label="
            confirming === true
              ? $t('COMMERCE.SUBSCRIPTIONS.CONFIRM_CANCEL')
              : $t('COMMERCE.SUBSCRIPTIONS.CANCEL_AT_PERIOD_END')
          "
          :is-loading="isCanceling"
          @click="cancel(true)"
        />
        <Button
          sm
          ruby
          outline
          :label="
            confirming === false
              ? $t('COMMERCE.SUBSCRIPTIONS.CONFIRM_CANCEL')
              : $t('COMMERCE.SUBSCRIPTIONS.CANCEL_NOW')
          "
          :is-loading="isCanceling"
          @click="cancel(false)"
        />
      </div>
    </div>
  </Dialog>
</template>
