<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import CommerceAPI from 'dashboard/api/commerce';
import ContactAPI from 'dashboard/api/contacts';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Enviar o documento: por uma conversa do cliente (o PDF vai anexo, com o link)
// ou por e-mail. Em branco, a mensagem e o assunto saem no idioma do documento.
const emit = defineEmits(['sent']);
const { t } = useI18n();
const getInbox = useMapGetter('inboxes/getInbox');

const dialogRef = ref(null);
const doc = ref(null);
const channel = ref('conversation');
const conversations = ref([]);
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
  conversations.value = [];
  if (document.contact_id) {
    const { data } = await ContactAPI.getConversations(document.contact_id);
    // A mais recente primeiro, com a caixa (nome dado pela conta) e a última
    // mensagem: só o número da conversa não diz qual é.
    conversations.value = data.payload
      .map(conversation => {
        const last = conversation.last_non_activity_message;
        return {
          id: conversation.id,
          status: conversation.status,
          inbox: getInbox.value(conversation.inbox_id)?.name || '',
          preview: last?.content || '',
          fromCustomer: last?.message_type === 0,
          lastActivityAt: conversation.last_activity_at,
        };
      })
      .sort((a, b) => b.lastActivityAt - a.lastActivityAt);
    const own = conversations.value.find(c => c.id === document.conversation_id);
    conversationId.value = (own || conversations.value[0])?.id || '';
  }
  channel.value = conversations.value.length ? 'conversation' : 'email';
  dialogRef.value.open();
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
        : { channel: 'email', to: to.value.trim(), subject: subject.value, body: body.value };
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
      <template v-if="channel === 'conversation'">
        <p v-if="!conversations.length" class="text-sm text-n-amber-11">
          {{ $t('COMMERCE.DOCUMENTS.NO_CONVERSATIONS') }}
        </p>
        <div v-else class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ $t('COMMERCE.DOCUMENTS.CONVERSATION') }}
          </span>
          <div
            class="flex flex-col overflow-y-auto border divide-y rounded-lg max-h-64 border-n-weak divide-n-weak"
          >
            <button
              v-for="conversation in conversations"
              :key="conversation.id"
              type="button"
              class="flex items-start gap-3 px-3 py-2 text-start"
              :class="
                conversationId === conversation.id
                  ? 'bg-n-blue-3'
                  : 'hover:bg-n-slate-2'
              "
              @click="conversationId = conversation.id"
            >
              <span
                class="mt-0.5 size-4 shrink-0"
                :class="
                  conversationId === conversation.id
                    ? 'i-lucide-circle-check text-n-blue-11'
                    : 'i-lucide-circle text-n-slate-8'
                "
              />
              <span class="flex flex-col min-w-0 gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ conversation.inbox }} · #{{ conversation.id }}
                  <span class="font-normal text-n-slate-11">
                    ·
                    {{
                      $t(
                        `COMMERCE.DOCUMENTS.CONVERSATION_STATUS.${conversation.status}`
                      )
                    }}
                    · {{ dynamicTime(conversation.lastActivityAt) }}
                  </span>
                </span>
                <span
                  v-if="conversation.preview"
                  class="text-xs truncate text-n-slate-11"
                >
                  {{
                    conversation.fromCustomer
                      ? $t('COMMERCE.DOCUMENTS.LAST_FROM_CUSTOMER')
                      : $t('COMMERCE.DOCUMENTS.LAST_FROM_US')
                  }}
                  {{ conversation.preview }}
                </span>
              </span>
            </button>
          </div>
        </div>
        <TextArea
          v-model="content"
          :label="$t('COMMERCE.DOCUMENTS.MESSAGE')"
          :placeholder="$t('COMMERCE.DOCUMENTS.MESSAGE_PLACEHOLDER')"
          :max-length="2000"
        />
      </template>
      <template v-else>
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
