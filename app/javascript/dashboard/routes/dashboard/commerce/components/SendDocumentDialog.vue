<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ConversationPicker from './ConversationPicker.vue';

// Enviar o documento: por uma conversa do cliente (o PDF vai anexo, com o link)
// ou por e-mail. Em branco, a mensagem e o assunto saem no idioma do documento.
const emit = defineEmits(['sent']);
const { t } = useI18n();

const dialogRef = ref(null);
const doc = ref(null);
const channel = ref('conversation');
const pickerRef = ref(null);
const conversationId = ref('');
const content = ref('');
const to = ref('');
const subject = ref('');
const body = ref('');
const isSending = ref(false);

const canSend = computed(() =>
  channel.value === 'conversation'
    ? Boolean(conversationId.value)
    : /.+@.+\..+/.test(to.value.trim())
);

const open = async document => {
  doc.value = document;
  content.value = '';
  subject.value = '';
  body.value = '';
  to.value = document.customer.email || '';
  channel.value = 'conversation';
  // O conteúdo do Dialog só existe aberto: a lista carrega depois.
  dialogRef.value.open();
  await nextTick();
  const count = await pickerRef.value.load(
    document.contact_id,
    document.conversation_id
  );
  if (!count) channel.value = 'email';
};

const send = async () => {
  isSending.value = true;
  try {
    const delivery =
      channel.value === 'conversation'
        ? {
            channel: 'conversation',
            conversation_id: conversationId.value,
            content: content.value,
          }
        : {
            channel: 'email',
            to: to.value.trim(),
            subject: subject.value,
            body: body.value,
          };
    const { data } = await CommerceAPI.deliverDocument(doc.value.id, delivery);
    emit('sent', data);
    useAlert(t('COMMERCE.DOCUMENTS.SENT_OK'));
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isSending.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    width="2xl"
    :title="$t('COMMERCE.DOCUMENTS.SEND_TITLE', { number: doc?.number })"
    :confirm-button-label="$t('COMMERCE.DOCUMENTS.SEND')"
    :disable-confirm-button="!canSend"
    :is-loading="isSending"
    @confirm="send"
  >
    <div class="flex flex-col gap-3">
      <div class="flex p-0.5 rounded-lg bg-n-slate-3 self-start">
        <button
          v-for="value in ['conversation', 'email']"
          :key="value"
          type="button"
          class="px-3 py-1 text-sm rounded-md"
          :class="
            channel === value
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-11'
          "
          @click="channel = value"
        >
          {{ $t(`COMMERCE.DOCUMENTS.CHANNEL.${value}`) }}
        </button>
      </div>
      <div v-show="channel === 'conversation'" class="flex flex-col gap-3">
        <ConversationPicker ref="pickerRef" v-model="conversationId" />
        <TextArea
          v-model="content"
          :label="$t('COMMERCE.DOCUMENTS.MESSAGE')"
          :placeholder="$t('COMMERCE.DOCUMENTS.MESSAGE_PLACEHOLDER')"
          :max-length="2000"
        />
      </div>
      <template v-if="channel === 'email'">
        <Input v-model="to" :label="$t('COMMERCE.DOCUMENTS.EMAIL_TO')" />
        <Input
          v-model="subject"
          :label="$t('COMMERCE.DOCUMENTS.EMAIL_SUBJECT')"
          :placeholder="$t('COMMERCE.DOCUMENTS.MESSAGE_PLACEHOLDER')"
        />
        <TextArea
          v-model="body"
          :label="$t('COMMERCE.DOCUMENTS.MESSAGE')"
          :placeholder="$t('COMMERCE.DOCUMENTS.MESSAGE_PLACEHOLDER')"
          :max-length="5000"
        />
      </template>
    </div>
  </Dialog>
</template>
