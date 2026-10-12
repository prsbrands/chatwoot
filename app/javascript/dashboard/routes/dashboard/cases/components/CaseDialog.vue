<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import CasesAPI from 'dashboard/api/cases';
import ContactAPI from 'dashboard/api/contacts';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CaseFieldInput from './CaseFieldInput.vue';
import { PRIORITIES } from '../constants';

// Abrir um caso. Da conversa ou do contato, o cliente já vem
// (open({ contact, conversationId })); da tela Cases, busca-se o contato. Ao
// escolher o tipo, prioridade e responsável vêm os padrões dele, e os campos
// próprios aparecem (os obrigatórios só são exigidos ao resolver).
const emit = defineEmits(['saved']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

const NOBODY = 0;
const dialogRef = ref(null);
const types = ref([]);
const contact = ref(null);
const conversationId = ref(null);
const contactQuery = ref('');
const contactResults = ref([]);
const form = ref({});
const isSaving = ref(false);

const activeTypes = computed(() => types.value.filter(type => type.active));
const typeOptions = computed(() =>
  activeTypes.value.map(type => ({ value: type.id, label: type.name }))
);
const selectedType = computed(() =>
  types.value.find(type => type.id === form.value.type_id)
);
const priorityOptions = computed(() =>
  PRIORITIES.map(value => ({ value, label: t(`CASES.PRIORITY.${value}`) }))
);
const assigneeOptions = computed(() => [
  { value: NOBODY, label: t('CASES.UNASSIGNED') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const canSave = computed(
  () => contact.value && form.value.type_id && form.value.title?.trim()
);

watch(
  () => form.value.type_id,
  () => {
    const type = selectedType.value;
    if (!type) return;
    form.value.priority = type.default_priority;
    form.value.assignee_id = type.default_assignee_id || NOBODY;
    form.value.field_values = {};
  }
);

const fetchTypes = async () => {
  const { data } = await CasesAPI.types();
  types.value = data.payload;
};

const open = async ({
  contact: preset = null,
  conversationId: conv = null,
} = {}) => {
  contact.value = preset;
  conversationId.value = conv;
  contactQuery.value = '';
  contactResults.value = [];
  form.value = { title: '', description: '', field_values: {} };
  if (!types.value.length) await fetchTypes();
  form.value.type_id = activeTypes.value[0]?.id;
  dialogRef.value.open();
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
  contact.value = { id: picked.id, name: picked.name };
  contactQuery.value = '';
  contactResults.value = [];
};

// Enter num campo também envia o formulário do diálogo.
const save = async () => {
  if (!canSave.value) return;
  const payload = {
    ...form.value,
    title: form.value.title.trim(),
    assignee_id: form.value.assignee_id || null,
    contact_id: contact.value.id,
    conversation_id: conversationId.value || undefined,
  };
  isSaving.value = true;
  try {
    const { data } = await CasesAPI.create(payload);
    emit('saved', data);
    dialogRef.value.close();
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        error.response?.data?.message ||
        t('CASES.API.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

// Os tipos já vêm na montagem: o diálogo abre na hora.
onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
  fetchTypes();
});

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    :title="$t('CASES.NEW')"
    :confirm-button-label="$t('CASES.CREATE')"
    :disable-confirm-button="!canSave"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ $t('CASES.CONTACT') }}
        </span>
        <div v-if="contact" class="flex items-center justify-between gap-2">
          <span class="text-sm text-n-slate-12">{{ contact.name }}</span>
          <button
            v-if="!conversationId"
            type="button"
            class="text-xs text-n-slate-11 hover:underline"
            @click="contact = null"
          >
            {{ $t('CASES.CHANGE_CONTACT') }}
          </button>
        </div>
        <div v-else class="relative">
          <Input
            v-model="contactQuery"
            :placeholder="$t('CASES.SEARCH_CONTACT')"
            @input="searchContacts"
          />
          <ul
            v-if="contactResults.length"
            class="absolute z-10 w-full mt-1 overflow-hidden list-none rounded-lg shadow-lg bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-weak"
          >
            <li v-for="result in contactResults" :key="result.id">
              <button
                type="button"
                class="w-full px-3 py-2 text-sm text-left text-n-slate-12 hover:bg-n-alpha-1"
                @click="pickContact(result)"
              >
                {{ result.name }}
                <span class="text-xs text-n-slate-11">
                  {{ result.phone_number || result.email }}
                </span>
              </button>
            </li>
          </ul>
        </div>
      </div>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('CASES.TYPE') }}
        <Select v-model="form.type_id" :options="typeOptions" />
      </label>
      <Input
        v-model="form.title"
        :label="$t('CASES.TITLE')"
        :placeholder="$t('CASES.TITLE_PLACEHOLDER')"
      />
      <TextArea
        v-model="form.description"
        :label="$t('CASES.DESCRIPTION')"
        :max-length="5000"
      />
      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('CASES.PRIORITY_LABEL') }}
          <Select v-model="form.priority" :options="priorityOptions" />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('CASES.ASSIGNEE') }}
          <Select v-model="form.assignee_id" :options="assigneeOptions" />
        </label>
      </div>
      <template v-if="selectedType?.fields.length">
        <CaseFieldInput
          v-for="field in selectedType.fields"
          :key="field.key"
          v-model="form.field_values[field.key]"
          :field="field"
        />
      </template>
    </div>
  </Dialog>
</template>
