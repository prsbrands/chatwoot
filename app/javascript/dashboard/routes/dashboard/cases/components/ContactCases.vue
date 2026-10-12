<script setup>
import { ref, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import CasesAPI from 'dashboard/api/cases';
import Button from 'dashboard/components-next/button/Button.vue';
import CaseDialog from './CaseDialog.vue';
import CaseRow from './CaseRow.vue';

// Os casos do cliente, no painel da conversa e na aba do contato: os ativos e
// o botão de abrir um caso (da conversa, já ligado a ela). Com `showClosed`,
// também os resolvidos e cancelados.
const props = defineProps({
  contact: { type: Object, default: null },
  conversationId: { type: [Number, String], default: null },
  showClosed: { type: Boolean, default: false },
});

const store = useStore();
const cases = ref([]);
const dialogRef = ref(null);

const fetchCases = async () => {
  cases.value = [];
  if (!props.contact?.id) return;
  const { data } = await CasesAPI.list({
    contact_id: props.contact.id,
    status: props.showClosed ? 'all' : 'active',
  });
  cases.value = data.payload;
};

const newCase = () =>
  dialogRef.value.open({
    contact: { id: props.contact.id, name: props.contact.name },
    conversationId: props.conversationId,
  });

const saved = () => {
  store.dispatch('cases/fetchOverdueCount');
  fetchCases();
};

watch(() => props.contact?.id, fetchCases, { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-3 px-4 py-2">
    <p v-if="!cases.length" class="m-0 text-sm text-n-slate-11">
      {{
        showClosed
          ? $t('CASES.EMPTY.contact')
          : $t('CASES.EMPTY.contact_active')
      }}
    </p>
    <ul v-else class="flex flex-col gap-3 m-0 list-none">
      <li v-for="kase in cases" :key="kase.id">
        <CaseRow :kase="kase" compact />
      </li>
    </ul>
    <Button
      xs
      slate
      faded
      icon="i-lucide-plus"
      class="self-start"
      :label="$t('CASES.NEW')"
      :disabled="!contact"
      @click="newCase"
    />
    <CaseDialog ref="dialogRef" @saved="saved" />
  </div>
</template>
