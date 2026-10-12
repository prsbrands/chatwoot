<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import CasesAPI from 'dashboard/api/cases';
import ContactAPI from 'dashboard/api/contacts';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import CaseFieldInput from '../components/CaseFieldInput.vue';
import CaseTimeline from '../components/CaseTimeline.vue';
import CloseCaseDialog from '../components/CloseCaseDialog.vue';
import {
  ACTIONS_BY_STATUS,
  PRIORITIES,
  PRIORITY_CLASSES,
  STATUS_CLASSES,
} from '../constants';

// Um caso: o que o cliente pediu, os campos do tipo, o histórico com as
// notas, e ao lado a situação, o responsável, a prioridade, o prazo, o
// contato e as conversas. Cada mudança vai direto para a API e volta o caso
// inteiro, com o histórico atualizado.
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { isAdmin } = useAdmin();
const { accountScopedRoute } = useAccount();
const agents = useMapGetter('agents/getAgents');

const NOBODY = 0;
const kase = ref(null);
const types = ref([]);
const isLoading = ref(true);
const isEditing = ref(false);
const draft = ref({});
const fieldValues = ref({});
const note = ref('');
const relayText = ref('');
const isRelaying = ref(false);
const contactConversations = ref([]);
const closeDialogRef = ref(null);

const caseId = computed(() => route.params.caseId);
const actions = computed(() => ACTIONS_BY_STATUS[kase.value?.status] || []);
const typeOptions = computed(() =>
  types.value
    .filter(type => type.active || type.id === kase.value?.type.id)
    .map(type => ({ value: type.id, label: type.name }))
);
const priorityOptions = computed(() =>
  PRIORITIES.map(value => ({ value, label: t(`CASES.PRIORITY.${value}`) }))
);
const assigneeOptions = computed(() => [
  { value: NOBODY, label: t('CASES.UNASSIGNED') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);
const fieldsChanged = computed(
  () =>
    JSON.stringify(fieldValues.value) !==
    JSON.stringify(kase.value?.field_values || {})
);
const unlinkedConversations = computed(() => {
  const linked = (kase.value?.conversations || []).map(c => c.id);
  return contactConversations.value.filter(c => !linked.includes(c.id));
});

// O <input type="datetime-local"> fala a hora local sem fuso.
const pad = number => String(number).padStart(2, '0');
const toLocalInput = epoch => {
  if (!epoch) return '';
  const date = new Date(epoch * 1000);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

const apply = data => {
  kase.value = data;
  fieldValues.value = { ...data.field_values };
  store.dispatch('cases/fetchOverdueCount');
};

const fail = error =>
  useAlert(
    error.response?.data?.error ||
      error.response?.data?.message ||
      t('CASES.API.ERROR')
  );

const fetchCase = async () => {
  isLoading.value = true;
  try {
    const { data } = await CasesAPI.show(caseId.value);
    apply(data);
    const { data: conversations } = await ContactAPI.getConversations(
      data.contact.id
    );
    contactConversations.value = conversations.payload;
  } finally {
    isLoading.value = false;
  }
};

const update = async changes => {
  try {
    const { data } = await CasesAPI.update(kase.value.id, changes);
    apply(data);
    return true;
  } catch (error) {
    fail(error);
    return false;
  }
};

const run = async (action, payload = {}) => {
  try {
    const { data } = await CasesAPI.action(kase.value.id, action, payload);
    apply(data);
    return true;
  } catch (error) {
    fail(error);
    return false;
  }
};

// Resolver pede os obrigatórios do tipo preenchidos e salvos.
const onAction = action => {
  const missing = kase.value.missing_required_fields;
  if (action === 'resolve' && (missing.length || fieldsChanged.value)) {
    const labels = kase.value.type_fields
      .filter(field => missing.includes(field.key))
      .map(field => field.label);
    useAlert(
      fieldsChanged.value
        ? t('CASES.FIELDS.SAVE_FIRST')
        : t('CASES.FIELDS.MISSING', { fields: labels.join(', ') })
    );
  } else if (action === 'resolve' || action === 'cancel') {
    closeDialogRef.value.open(action);
  } else run(action);
};

const startEditing = () => {
  draft.value = {
    title: kase.value.title,
    description: kase.value.description || '',
  };
  isEditing.value = true;
};
const saveText = async () => {
  if (
    await update({
      title: draft.value.title.trim(),
      description: draft.value.description,
    })
  ) {
    isEditing.value = false;
  }
};

const changeDue = value => {
  if (value === toLocalInput(kase.value.due_at)) return;
  update({ due_at: value ? new Date(value).toISOString() : null });
};

// A IA diz ao cliente, na conversa do caso, o que a equipe escreveu: uma
// resposta, ou uma pergunta (o caso passa a esperar o cliente quando sai).
const canRelay = computed(
  () =>
    kase.value?.conversations.length &&
    ['open', 'in_progress', 'waiting_customer'].includes(kase.value.status)
);
const relay = async mode => {
  isRelaying.value = true;
  if (await run('relay', { body: relayText.value.trim(), mode })) {
    relayText.value = '';
  }
  isRelaying.value = false;
};

const addNote = async () => {
  await run('note', { body: note.value.trim() });
  note.value = '';
};

const remove = async () => {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('CASES.DELETE_CONFIRM', { number: kase.value.number })))
    return;
  try {
    await CasesAPI.delete(kase.value.id);
    store.dispatch('cases/fetchOverdueCount');
    router.push(accountScopedRoute('cases_index'));
  } catch (error) {
    fail(error);
  }
};

watch(caseId, fetchCase);
onMounted(async () => {
  if (!agents.value.length) store.dispatch('agents/get');
  fetchCase();
  const { data } = await CasesAPI.types();
  types.value = data.payload;
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div v-if="isLoading && !kase" class="flex px-6 py-5">
      <Spinner />
    </div>

    <template v-else-if="kase">
      <header class="flex flex-col gap-2 px-6 py-5 border-b border-n-weak">
        <router-link
          :to="accountScopedRoute('cases_index')"
          class="flex items-center gap-1 text-xs text-n-slate-11 hover:underline w-fit"
        >
          <span class="i-lucide-arrow-left size-3" />
          {{ $t('CASES.BACK') }}
        </router-link>
        <div class="flex flex-wrap items-center gap-2 text-sm text-n-slate-11">
          <span
            class="rounded-full size-2.5"
            :style="{ backgroundColor: kase.type.color }"
          />
          <span class="font-medium text-n-slate-12">{{ kase.number }}</span>
          <span>{{ kase.type.name }}</span>
          <span class="px-2 rounded-md" :class="STATUS_CLASSES[kase.status]">
            {{ $t(`CASES.STATUS.${kase.status}`) }}
          </span>
          <span v-if="kase.outcome" class="text-n-slate-11">
            · {{ $t(`CASES.OUTCOME.${kase.outcome}`) }}
          </span>
          <span v-if="kase.overdue" class="font-medium text-n-ruby-11">
            · {{ $t('CASES.OVERDUE') }}
          </span>
          <span v-if="kase.source === 'ai'" class="text-n-slate-11">
            · {{ $t('CASES.OPENED_BY_AI') }}
          </span>
        </div>
        <div v-if="!isEditing" class="flex items-start justify-between gap-4">
          <h1 class="text-heading-2 text-n-slate-12">{{ kase.title }}</h1>
          <Button
            xs
            ghost
            slate
            icon="i-lucide-pencil"
            :title="$t('CASES.EDIT')"
            @click="startEditing"
          />
        </div>
        <div class="flex flex-wrap gap-2">
          <Button
            v-for="action in actions"
            :key="action"
            sm
            :slate="action !== 'resolve'"
            :faded="action !== 'resolve'"
            :teal="action === 'resolve'"
            :label="$t(`CASES.ACTIONS.${action}`)"
            @click="onAction(action)"
          />
          <Button
            v-if="isAdmin"
            sm
            ruby
            ghost
            icon="i-lucide-trash-2"
            :title="$t('CASES.DELETE')"
            @click="remove"
          />
        </div>
      </header>

      <div class="grid gap-6 px-6 py-5 lg:grid-cols-[minmax(0,1fr)_18rem]">
        <div class="flex flex-col gap-6 min-w-0">
          <section v-if="isEditing" class="flex flex-col gap-3">
            <Input v-model="draft.title" :label="$t('CASES.TITLE')" />
            <TextArea
              v-model="draft.description"
              :label="$t('CASES.DESCRIPTION')"
              :max-length="5000"
            />
            <div class="flex gap-2">
              <Button
                sm
                :label="$t('CASES.SAVE')"
                :disabled="!draft.title.trim()"
                @click="saveText"
              />
              <Button
                sm
                slate
                faded
                :label="$t('CASES.CANCEL_EDIT')"
                @click="isEditing = false"
              />
            </div>
          </section>
          <p
            v-else-if="kase.description"
            class="m-0 text-sm whitespace-pre-wrap text-n-slate-12"
          >
            {{ kase.description }}
          </p>

          <p
            v-if="kase.resolution"
            class="px-3 py-2 m-0 text-sm whitespace-pre-wrap rounded-lg bg-n-teal-2 text-n-slate-12"
          >
            {{ kase.resolution }}
          </p>

          <section
            v-if="kase.type_fields.length"
            class="flex flex-col gap-3 p-4 rounded-xl bg-n-card outline outline-1 outline-n-container"
          >
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ $t('CASES.FIELDS.HEADER') }}
            </h2>
            <CaseFieldInput
              v-for="field in kase.type_fields"
              :key="field.key"
              v-model="fieldValues[field.key]"
              :field="field"
            />
            <p
              v-if="kase.missing_required_fields.length"
              class="m-0 text-xs text-n-amber-11"
            >
              {{ $t('CASES.FIELDS.REQUIRED_HINT') }}
            </p>
            <Button
              v-if="fieldsChanged"
              sm
              class="self-start"
              :label="$t('CASES.SAVE')"
              @click="update({ field_values: fieldValues })"
            />
          </section>

          <section
            v-if="canRelay"
            class="flex flex-col gap-2 p-4 rounded-xl bg-n-card outline outline-1 outline-n-container"
          >
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ $t('CASES.RELAY.HEADER') }}
            </h2>
            <p class="m-0 text-xs text-n-slate-11">
              {{ $t('CASES.RELAY.HINT') }}
            </p>
            <TextArea
              v-model="relayText"
              :placeholder="$t('CASES.RELAY.PLACEHOLDER')"
              :max-length="2000"
            />
            <div class="flex flex-wrap gap-2">
              <Button
                sm
                icon="i-lucide-send"
                :label="$t('CASES.RELAY.ANSWER')"
                :disabled="!relayText.trim() || isRelaying"
                @click="relay('answer')"
              />
              <Button
                sm
                slate
                faded
                icon="i-lucide-message-circle-question"
                :label="$t('CASES.RELAY.ASK')"
                :disabled="!relayText.trim() || isRelaying"
                @click="relay('ask')"
              />
            </div>
          </section>

          <section class="flex flex-col gap-3">
            <h2 class="text-sm font-medium text-n-slate-12">
              {{ $t('CASES.TIMELINE') }}
            </h2>
            <TextArea
              v-model="note"
              :placeholder="$t('CASES.NOTE_PLACEHOLDER')"
              :max-length="5000"
            />
            <Button
              sm
              class="self-start"
              :label="$t('CASES.ADD_NOTE')"
              :disabled="!note.trim()"
              @click="addNote"
            />
            <CaseTimeline
              :events="kase.events"
              :types="types"
              :fields="kase.type_fields"
            />
          </section>
        </div>

        <aside class="flex flex-col gap-4">
          <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
            {{ $t('CASES.ASSIGNEE') }}
            <Select
              :model-value="kase.assignee?.id || NOBODY"
              :options="assigneeOptions"
              @update:model-value="
                value => update({ assignee_id: value || null })
              "
            />
          </label>
          <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
            {{ $t('CASES.PRIORITY_LABEL') }}
            <Select
              :model-value="kase.priority"
              :options="priorityOptions"
              :class="PRIORITY_CLASSES[kase.priority]"
              @update:model-value="value => update({ priority: value })"
            />
          </label>
          <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
            {{ $t('CASES.TYPE') }}
            <Select
              :model-value="kase.type.id"
              :options="typeOptions"
              @update:model-value="value => update({ type_id: value })"
            />
          </label>
          <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
            {{ $t('CASES.DUE') }}
            <Input
              :model-value="toLocalInput(kase.due_at)"
              type="datetime-local"
              :message="kase.paused_at ? $t('CASES.PAUSED_HINT') : ''"
              @blur="event => changeDue(event.target.value)"
            />
          </label>

          <div class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ $t('CASES.CONTACT') }}
            </span>
            <router-link
              :to="
                accountScopedRoute('contacts_edit', {
                  contactId: kase.contact.id,
                })
              "
              class="text-sm text-n-slate-12 hover:underline"
            >
              {{ kase.contact.name }}
            </router-link>
          </div>
          <div v-if="kase.deal" class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ $t('CASES.DEAL') }}
            </span>
            <span class="text-sm text-n-slate-12">{{ kase.deal.title }}</span>
          </div>

          <div class="flex flex-col gap-2">
            <span class="text-label-small text-n-slate-11">
              {{ $t('CASES.CONVERSATIONS') }}
            </span>
            <router-link
              v-for="conversation in kase.conversations"
              :key="conversation.id"
              :to="
                accountScopedRoute('inbox_conversation', {
                  conversation_id: conversation.id,
                })
              "
              class="text-sm text-n-slate-12 hover:underline"
            >
              #{{ conversation.id }} · {{ conversation.inbox_name }}
              <span class="text-xs text-n-slate-11">
                · {{ dynamicTime(conversation.last_activity_at) }}
              </span>
            </router-link>
            <p
              v-if="!kase.conversations.length"
              class="m-0 text-xs text-n-slate-11"
            >
              {{ $t('CASES.NO_CONVERSATIONS') }}
            </p>
            <button
              v-for="conversation in unlinkedConversations"
              :key="conversation.id"
              type="button"
              class="flex items-center gap-1 text-xs text-start text-n-slate-11 hover:text-n-slate-12"
              @click="
                run('link_conversation', { conversation_id: conversation.id })
              "
            >
              <span class="i-lucide-link size-3" />
              {{ $t('CASES.LINK_CONVERSATION', { id: conversation.id }) }}
            </button>
          </div>
        </aside>
      </div>
    </template>

    <CloseCaseDialog ref="closeDialogRef" @confirm="run" />
  </section>
</template>
