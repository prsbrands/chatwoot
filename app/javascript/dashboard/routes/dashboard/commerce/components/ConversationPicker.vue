<script setup>
import { ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ContactAPI from 'dashboard/api/contacts';

// As conversas do cliente para enviar algo (documento, link da assinatura):
// a mais recente primeiro, com a caixa (nome dado pela conta) e a última
// mensagem, porque só o número da conversa não diz qual é. Caixa API sem
// webhook (a de voz, que só guarda a transcrição da ligação) não entrega nada
// ao cliente e fica fora. load() começa na conversa `preferredId`, se ela
// estiver na lista, ou na mais recente, e devolve quantas há.
const selected = defineModel({ type: [Number, String], default: '' });
const getInbox = useMapGetter('inboxes/getInbox');
const conversations = ref([]);

const delivers = conversation => {
  const inbox = getInbox.value(conversation.inbox_id);
  return inbox?.channel_type !== 'Channel::Api' || Boolean(inbox.webhook_url);
};

const load = async (contactId, preferredId = null) => {
  conversations.value = [];
  if (contactId) {
    const { data } = await ContactAPI.getConversations(contactId);
    conversations.value = data.payload
      .filter(delivers)
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
  }
  const own = conversations.value.find(c => c.id === preferredId);
  selected.value = (own || conversations.value[0])?.id || '';
  return conversations.value.length;
};

defineExpose({ load });
</script>

<template>
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
          selected === conversation.id ? 'bg-n-blue-3' : 'hover:bg-n-slate-2'
        "
        @click="selected = conversation.id"
      >
        <span
          class="mt-0.5 size-4 shrink-0"
          :class="
            selected === conversation.id
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
</template>
