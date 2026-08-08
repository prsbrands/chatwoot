<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const TABS = ['personas', 'knowledge', 'channels', 'providers'];
const activeTab = ref('personas');

const personas = ref([]);
const docs = ref([]);
const routes = ref([]);
const providers = ref([]);
const isLoading = ref(true);

const API_STYLES = [
  { value: 'openai', label: 'OpenAI-compatible' },
  { value: 'anthropic', label: 'Anthropic Messages' },
];

const providerDialogRef = ref(null);
const providerForm = ref({});
const isNewProvider = ref(false);
const isSavingProvider = ref(false);
const syncingProviderId = ref(null);

const personaDialogRef = ref(null);
const personaForm = ref({});
const isNewPersona = ref(false);
const isSavingPersona = ref(false);

const docDialogRef = ref(null);
const docForm = ref({});
const isNewDoc = ref(false);
const isSavingDoc = ref(false);

const deleteDialogRef = ref(null);
const deleteTarget = ref(null); // { kind: 'persona' | 'doc', record }

const inboxes = computed(() => getters['inboxes/getInboxes'].value);

const personaOptions = computed(() =>
  personas.value.map(persona => ({
    value: persona.id,
    label: persona.display_name + ' (' + persona.slug + ')',
  }))
);

const providerOptions = computed(() =>
  providers.value
    .filter(provider => provider.is_active)
    .map(provider => ({ value: provider.slug, label: provider.label }))
);

// Modelos do fornecedor selecionado alimentam o datalist: o campo continua
// aberto para digitar um id que ainda não está no catálogo.
const modelSuggestions = computed(() => {
  const provider = providers.value.find(
    candidate => candidate.slug === personaForm.value.provider
  );
  return (provider?.models || []).map(model => model.id);
});

const personaName = id =>
  personas.value.find(persona => persona.id === id)?.display_name;

// Um provider que não existe no catálogo, ou que precisa de chave e não tem,
// falha só na hora de responder — melhor avisar já no card.
const providerIssue = persona => {
  if (!providers.value.length) return '';
  const provider = providers.value.find(
    candidate => candidate.slug === persona.provider
  );
  if (!provider) {
    return t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.UNKNOWN_PROVIDER', {
      provider: persona.provider,
    });
  }
  if (provider.slug !== 'openrouter' && !provider.api_key) {
    return t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MISSING_KEY', {
      provider: provider.label,
    });
  }
  return '';
};

const docCountFor = persona => {
  const linked = (persona.bot_persona_knowledge || []).length;
  const globals = docs.value.filter(doc => doc.is_global).length;
  return linked + globals;
};

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.BOTLAYER.API.ERROR')
  );

const fetchAll = async () => {
  try {
    const [personasRes, docsRes, routesRes, providersRes] = await Promise.all([
      BotlayerAPI.personas(),
      BotlayerAPI.knowledge(),
      BotlayerAPI.routes(),
      BotlayerAPI.providers(),
    ]);
    personas.value = personasRes.data.personas;
    docs.value = docsRes.data.docs;
    routes.value = routesRes.data.routes;
    providers.value = providersRes.data.providers;
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

// --- Personas ---

const openPersonaDialog = persona => {
  isNewPersona.value = !persona;
  personaForm.value = persona
    ? {
        id: persona.id,
        slug: persona.slug,
        display_name: persona.display_name,
        description: persona.description || '',
        system_prompt: persona.system_prompt,
        provider: persona.provider,
        model: persona.model,
        fallback_model: persona.fallback_model || '',
        temperature: persona.temperature,
        max_tokens: persona.max_tokens,
        is_active: persona.is_active,
        keywords: (persona.handoff_rules?.keywords || []).join(', '),
        max_turns: persona.handoff_rules?.max_turns || null,
        handoff_rules: persona.handoff_rules || {},
      }
    : {
        slug: '',
        display_name: '',
        description: '',
        system_prompt: '',
        provider: 'openrouter',
        model: '',
        fallback_model: '',
        temperature: 0.6,
        max_tokens: 1200,
        is_active: true,
        keywords: '',
        max_turns: null,
        handoff_rules: {},
      };
  personaDialogRef.value.open();
};

const personaPayload = () => {
  const form = personaForm.value;
  return {
    slug: form.slug,
    display_name: form.display_name,
    description: form.description,
    system_prompt: form.system_prompt,
    provider: form.provider,
    model: form.model,
    fallback_model: form.fallback_model || null,
    temperature: Number(form.temperature),
    max_tokens: Number(form.max_tokens),
    is_active: form.is_active,
    handoff_rules: {
      ...form.handoff_rules,
      keywords: form.keywords
        .split(',')
        .map(keyword => keyword.trim())
        .filter(Boolean),
      max_turns: form.max_turns ? Number(form.max_turns) : null,
    },
  };
};

const savePersona = async () => {
  isSavingPersona.value = true;
  try {
    if (isNewPersona.value) {
      await BotlayerAPI.createPersona(personaPayload());
    } else {
      await BotlayerAPI.updatePersona(personaForm.value.id, personaPayload());
    }
    personaDialogRef.value.close();
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
    fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    isSavingPersona.value = false;
  }
};

// --- Knowledge ---

const openDocDialog = doc => {
  isNewDoc.value = !doc;
  docForm.value = doc
    ? {
        id: doc.id,
        slug: doc.slug,
        title: doc.title,
        content: doc.content,
        is_global: doc.is_global,
        priority: doc.priority,
        is_active: doc.is_active,
        persona_ids: (doc.bot_persona_knowledge || []).map(
          link => link.persona_id
        ),
      }
    : {
        slug: '',
        title: '',
        content: '',
        is_global: true,
        priority: 100,
        is_active: true,
        persona_ids: [],
      };
  docDialogRef.value.open();
};

const toggleDocPersona = personaId => {
  const ids = docForm.value.persona_ids;
  docForm.value.persona_ids = ids.includes(personaId)
    ? ids.filter(id => id !== personaId)
    : [...ids, personaId];
};

const saveDoc = async () => {
  isSavingDoc.value = true;
  const form = docForm.value;
  const payload = {
    slug: form.slug,
    title: form.title,
    content: form.content,
    is_global: form.is_global,
    priority: Number(form.priority),
    is_active: form.is_active,
    persona_ids: form.persona_ids,
  };
  try {
    if (isNewDoc.value) {
      await BotlayerAPI.createKnowledge(payload);
    } else {
      await BotlayerAPI.updateKnowledge(form.id, payload);
    }
    docDialogRef.value.close();
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
    fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    isSavingDoc.value = false;
  }
};

// --- Providers ---

const openProviderDialog = provider => {
  isNewProvider.value = !provider;
  providerForm.value = provider
    ? {
        id: provider.id,
        slug: provider.slug,
        label: provider.label,
        base_url: provider.base_url,
        api_style: provider.api_style,
        api_key: '',
        has_key: Boolean(provider.api_key),
        is_active: provider.is_active,
      }
    : {
        slug: '',
        label: '',
        base_url: '',
        api_style: 'openai',
        api_key: '',
        has_key: false,
        is_active: true,
      };
  providerDialogRef.value.open();
};

const saveProvider = async () => {
  isSavingProvider.value = true;
  const form = providerForm.value;
  const payload = {
    slug: form.slug,
    label: form.label,
    base_url: form.base_url,
    api_style: form.api_style,
    api_key: form.api_key,
    is_active: form.is_active,
  };
  try {
    if (isNewProvider.value) await BotlayerAPI.createProvider(payload);
    else await BotlayerAPI.updateProvider(form.id, payload);
    providerDialogRef.value.close();
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
    fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    isSavingProvider.value = false;
  }
};

const syncModels = async provider => {
  syncingProviderId.value = provider.id;
  try {
    const { data } = await BotlayerAPI.syncModels(provider.id);
    useAlert(
      t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.SYNCED', {
        count: (data.models || []).length,
      })
    );
    fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    syncingProviderId.value = null;
  }
};

// --- Delete (personas + docs + providers) ---

const openDeleteDialog = (kind, record) => {
  deleteTarget.value = { kind, record };
  deleteDialogRef.value.open();
};

const confirmDelete = async () => {
  const { kind, record } = deleteTarget.value;
  try {
    if (kind === 'persona') await BotlayerAPI.deletePersona(record.id);
    else if (kind === 'provider') await BotlayerAPI.deleteProvider(record.id);
    else await BotlayerAPI.deleteKnowledge(record.id);
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.DELETED'));
    fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    deleteDialogRef.value.close();
  }
};

// --- Channels ---

const channelRows = computed(() =>
  inboxes.value.map(inbox => {
    const route = routes.value.find(
      candidate => candidate.chatwoot_inbox_id === inbox.id
    );
    return { inbox, route };
  })
);

const draftRoutes = ref({});

const draftFor = row =>
  draftRoutes.value[row.inbox.id] || {
    persona_id: row.route?.persona_id || null,
    is_active: row.route?.is_active || false,
  };

const setDraft = (row, patch) => {
  draftRoutes.value = {
    ...draftRoutes.value,
    [row.inbox.id]: { ...draftFor(row), ...patch },
  };
};

const saveRoute = async row => {
  const draft = draftFor(row);
  if (!draft.persona_id) return;
  try {
    await BotlayerAPI.upsertRoute({
      chatwoot_inbox_id: row.inbox.id,
      persona_id: draft.persona_id,
      is_active: draft.is_active,
    });
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
    delete draftRoutes.value[row.inbox.id];
    fetchAll();
  } catch (error) {
    alertError(error);
  }
};

const removeRoute = async row => {
  try {
    await BotlayerAPI.deleteRoute(row.route.id);
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.DELETED'));
    delete draftRoutes.value[row.inbox.id];
    fetchAll();
  } catch (error) {
    alertError(error);
  }
};

onMounted(() => {
  fetchAll();
  store.dispatch('inboxes/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('INTEGRATION_SETTINGS.BOTLAYER.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.BOTLAYER.HEADER')"
        :description="$t('INTEGRATION_SETTINGS.BOTLAYER.DESCRIPTION')"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-4">
        <div class="flex gap-1 border-b border-n-weak">
          <button
            v-for="tab in TABS"
            :key="tab"
            class="px-4 py-2 text-sm font-medium -mb-px border-b-2"
            :class="
              activeTab === tab
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTab = tab"
          >
            {{ $t(`INTEGRATION_SETTINGS.BOTLAYER.TABS.${tab.toUpperCase()}`) }}
          </button>
        </div>

        <!-- Personas -->
        <div v-if="activeTab === 'personas'" class="flex flex-col gap-4">
          <div class="flex justify-end">
            <Button
              blue
              sm
              icon="i-lucide-circle-plus"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.NEW')"
              @click="openPersonaDialog(null)"
            />
          </div>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div
              v-for="persona in personas"
              :key="persona.id"
              class="flex flex-col gap-2 rounded-xl bg-n-card p-4 outline outline-1 outline-n-container"
            >
              <div class="flex items-start justify-between">
                <div>
                  <p class="font-medium text-n-slate-12">
                    {{ persona.display_name }}
                    <span class="text-xs text-n-slate-10">
                      ({{ persona.slug }})
                    </span>
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{ persona.provider }} · {{ persona.model }}
                  </p>
                </div>
                <span
                  class="rounded-md px-2 py-0.5 text-xs font-medium"
                  :class="
                    persona.is_active
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-slate-3 text-n-slate-11'
                  "
                >
                  {{
                    persona.is_active
                      ? $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE')
                      : $t('INTEGRATION_SETTINGS.BOTLAYER.INACTIVE')
                  }}
                </span>
              </div>
              <p class="line-clamp-2 text-sm text-n-slate-11">
                {{ persona.description || persona.system_prompt }}
              </p>
              <p
                v-if="providerIssue(persona)"
                class="flex items-center gap-1 text-xs text-n-ruby-11"
              >
                <span class="i-lucide-triangle-alert size-3.5 shrink-0" />
                {{ providerIssue(persona) }}
              </p>
              <div class="flex items-center justify-between">
                <span class="text-xs text-n-slate-10">
                  {{
                    $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.DOCS_COUNT', {
                      count: docCountFor(persona),
                    })
                  }}
                  · temp {{ persona.temperature }} ·
                  {{ persona.max_tokens }} tokens
                </span>
                <div class="flex gap-1">
                  <Button
                    sm
                    slate
                    ghost
                    icon="i-lucide-pencil"
                    @click="openPersonaDialog(persona)"
                  />
                  <Button
                    sm
                    ruby
                    ghost
                    icon="i-lucide-trash-2"
                    @click="openDeleteDialog('persona', persona)"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Knowledge -->
        <div v-if="activeTab === 'knowledge'" class="flex flex-col gap-4">
          <div class="flex justify-end">
            <Button
              blue
              sm
              icon="i-lucide-circle-plus"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.NEW')"
              @click="openDocDialog(null)"
            />
          </div>
          <div class="flex flex-col divide-y divide-n-weak">
            <div
              v-for="doc in docs"
              :key="doc.id"
              class="flex items-center justify-between gap-4 py-3"
            >
              <div class="min-w-0">
                <p class="truncate font-medium text-n-slate-12">
                  {{ doc.title }}
                  <span class="text-xs text-n-slate-10">({{ doc.slug }})</span>
                </p>
                <p class="text-xs text-n-slate-11">
                  {{ (doc.content || '').length }}
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.CHARS') }}
                  ·
                  <template v-if="doc.is_global">
                    {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.GLOBAL') }}
                  </template>
                  <template v-else>
                    {{
                      (doc.bot_persona_knowledge || [])
                        .map(link => personaName(link.persona_id))
                        .filter(Boolean)
                        .join(', ') ||
                      $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.UNLINKED')
                    }}
                  </template>
                </p>
              </div>
              <div class="flex shrink-0 gap-1">
                <Button
                  sm
                  slate
                  ghost
                  icon="i-lucide-pencil"
                  @click="openDocDialog(doc)"
                />
                <Button
                  sm
                  ruby
                  ghost
                  icon="i-lucide-trash-2"
                  @click="openDeleteDialog('doc', doc)"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Channels -->
        <div v-if="activeTab === 'channels'" class="flex flex-col gap-2">
          <p class="text-sm text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.HELP') }}
          </p>
          <table class="min-w-full divide-y divide-n-weak">
            <thead>
              <tr class="text-left text-sm text-n-slate-11">
                <th class="py-2 pr-4 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.INBOX') }}
                </th>
                <th class="py-2 pr-4 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.PERSONA') }}
                </th>
                <th class="py-2 pr-4 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.ACTIVE') }}
                </th>
                <th class="py-2 font-medium text-right">
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.ACTIONS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="row in channelRows"
                :key="row.inbox.id"
                class="text-sm"
              >
                <td class="py-2 pr-4 text-n-slate-12">{{ row.inbox.name }}</td>
                <td class="py-2 pr-4">
                  <Select
                    :model-value="draftFor(row).persona_id"
                    :options="personaOptions"
                    :placeholder="
                      $t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.NO_PERSONA')
                    "
                    @update:model-value="
                      value => setDraft(row, { persona_id: value })
                    "
                  />
                </td>
                <td class="py-2 pr-4">
                  <Switch
                    :model-value="draftFor(row).is_active"
                    @update:model-value="
                      value => setDraft(row, { is_active: value })
                    "
                  />
                </td>
                <td class="py-2 text-right whitespace-nowrap">
                  <Button
                    sm
                    blue
                    ghost
                    :label="$t('INTEGRATION_SETTINGS.BOTLAYER.CHANNELS.SAVE')"
                    :disabled="!draftFor(row).persona_id"
                    @click="saveRoute(row)"
                  />
                  <Button
                    v-if="row.route"
                    sm
                    ruby
                    ghost
                    icon="i-lucide-trash-2"
                    @click="removeRoute(row)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Providers -->
        <div v-if="activeTab === 'providers'" class="flex flex-col gap-4">
          <div class="flex items-center justify-between gap-4">
            <p class="text-sm text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.HELP') }}
            </p>
            <Button
              blue
              sm
              icon="i-lucide-circle-plus"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.NEW')"
              @click="openProviderDialog(null)"
            />
          </div>
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div
              v-for="provider in providers"
              :key="provider.id"
              class="flex flex-col gap-2 rounded-xl bg-n-card p-4 outline outline-1 outline-n-container"
            >
              <div class="flex items-start justify-between">
                <div class="min-w-0">
                  <p class="font-medium text-n-slate-12">
                    {{ provider.label }}
                    <span class="text-xs text-n-slate-10">
                      ({{ provider.slug }})
                    </span>
                  </p>
                  <p class="truncate text-xs text-n-slate-11">
                    {{ provider.base_url }}
                  </p>
                </div>
                <span
                  class="shrink-0 rounded-md px-2 py-0.5 text-xs font-medium"
                  :class="
                    provider.api_key
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-amber-3 text-n-amber-11'
                  "
                >
                  {{
                    provider.api_key
                      ? $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.HAS_KEY')
                      : $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.NO_KEY')
                  }}
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-xs text-n-slate-10">
                  {{
                    $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.MODEL_COUNT', {
                      count: (provider.models || []).length,
                    })
                  }}
                  · {{ provider.api_style }}
                </span>
                <div class="flex gap-1">
                  <Button
                    sm
                    slate
                    ghost
                    icon="i-lucide-refresh-cw"
                    :is-loading="syncingProviderId === provider.id"
                    :label="
                      $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.SYNC')
                    "
                    @click="syncModels(provider)"
                  />
                  <Button
                    sm
                    slate
                    ghost
                    icon="i-lucide-pencil"
                    @click="openProviderDialog(provider)"
                  />
                  <Button
                    sm
                    ruby
                    ghost
                    icon="i-lucide-trash-2"
                    @click="openDeleteDialog('provider', provider)"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Provider dialog -->
      <Dialog
        ref="providerDialogRef"
        :title="
          isNewProvider
            ? $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.NEW')
            : $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.EDIT')
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.BOTLAYER.SAVE')"
        :is-loading="isSavingProvider"
        :disable-confirm-button="
          isSavingProvider ||
          !providerForm.label ||
          !providerForm.slug ||
          !providerForm.base_url
        "
        @confirm="saveProvider"
      >
        <div class="flex flex-col gap-4">
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="providerForm.label"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.LABEL')"
              placeholder="Groq"
            />
            <Input
              v-model="providerForm.slug"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SLUG')"
              :disabled="!isNewProvider"
              placeholder="groq"
            />
          </div>
          <Input
            v-model="providerForm.base_url"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.BASE_URL')"
            placeholder="https://api.groq.com/openai/v1"
            :message="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.BASE_URL_HELP')"
          />
          <div class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.API_STYLE') }}
            </span>
            <Select v-model="providerForm.api_style" :options="API_STYLES" />
          </div>
          <Input
            v-model="providerForm.api_key"
            type="password"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.API_KEY')"
            :placeholder="
              providerForm.has_key
                ? $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.KEY_KEEP')
                : 'sk-...'
            "
            :message="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.API_KEY_HELP')"
          />
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE') }}
            </span>
            <Switch v-model="providerForm.is_active" />
          </div>
        </div>
      </Dialog>

      <!-- Persona dialog -->
      <Dialog
        ref="personaDialogRef"
        width="2xl"
        overflow-y-auto
        :title="
          isNewPersona
            ? $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.NEW')
            : $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.EDIT')
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.BOTLAYER.SAVE')"
        :is-loading="isSavingPersona"
        :disable-confirm-button="
          isSavingPersona ||
          !personaForm.display_name ||
          !personaForm.slug ||
          !personaForm.model
        "
        @confirm="savePersona"
      >
        <div class="flex flex-col gap-4">
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="personaForm.display_name"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.NAME')"
            />
            <Input
              v-model="personaForm.slug"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SLUG')"
              :disabled="!isNewPersona"
            />
          </div>
          <Input
            v-model="personaForm.description"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.DESCRIPTION')"
          />
          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.PROMPT') }}
            </span>
            <textarea
              v-model="personaForm.system_prompt"
              rows="14"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-black2 p-3 font-mono text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.PROMPT_HELP') }}
            </span>
          </div>
          <div class="grid grid-cols-3 gap-3">
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.PROVIDER') }}
              </span>
              <Select v-model="personaForm.provider" :options="providerOptions" />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MODEL') }}
              </span>
              <input
                v-model="personaForm.model"
                list="botlayer-models"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-black2 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                :placeholder="modelSuggestions[0] || 'provider/model-id'"
              />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.FALLBACK') }}
              </span>
              <input
                v-model="personaForm.fallback_model"
                list="botlayer-models"
                class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-black2 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
                :placeholder="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.OPTIONAL')"
              />
            </div>
            <datalist id="botlayer-models">
              <option v-for="id in modelSuggestions" :key="id" :value="id" />
            </datalist>
          </div>
          <p class="-mt-2 text-xs text-n-slate-11">
            {{
              modelSuggestions.length
                ? $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MODEL_HELP', {
                    count: modelSuggestions.length,
                  })
                : $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MODEL_EMPTY')
            }}
          </p>
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="personaForm.temperature"
              type="number"
              step="0.1"
              min="0"
              max="2"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TEMPERATURE')"
            />
            <Input
              v-model="personaForm.max_tokens"
              type="number"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MAX_TOKENS')"
            />
          </div>
          <Input
            v-model="personaForm.keywords"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.KEYWORDS')"
            :message="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.KEYWORDS_HELP')"
          />
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="personaForm.max_turns"
              type="number"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MAX_TURNS')"
            />
            <div class="flex items-center justify-between gap-2 pt-6">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE') }}
              </span>
              <Switch v-model="personaForm.is_active" />
            </div>
          </div>
        </div>
      </Dialog>

      <!-- Knowledge dialog -->
      <Dialog
        ref="docDialogRef"
        width="2xl"
        overflow-y-auto
        :title="
          isNewDoc
            ? $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.NEW')
            : $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.EDIT')
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.BOTLAYER.SAVE')"
        :is-loading="isSavingDoc"
        :disable-confirm-button="isSavingDoc || !docForm.title || !docForm.slug"
        @confirm="saveDoc"
      >
        <div class="flex flex-col gap-4">
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="docForm.title"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.TITLE')"
            />
            <Input
              v-model="docForm.slug"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SLUG')"
              :disabled="!isNewDoc"
            />
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.CONTENT') }}
            </span>
            <textarea
              v-model="docForm.content"
              rows="14"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-black2 p-3 font-mono text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
            />
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.CONTENT_HELP') }}
            </span>
          </div>
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.GLOBAL_TOGGLE') }}
            </span>
            <Switch v-model="docForm.is_global" />
          </div>
          <div v-if="!docForm.is_global" class="flex flex-col gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.LINKED') }}
            </span>
            <label
              v-for="persona in personas"
              :key="persona.id"
              class="flex items-center gap-2 text-sm text-n-slate-12"
            >
              <input
                type="checkbox"
                class="rounded border-n-weak"
                :checked="docForm.persona_ids.includes(persona.id)"
                @change="toggleDocPersona(persona.id)"
              />
              {{ persona.display_name }} ({{ persona.slug }})
            </label>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="docForm.priority"
              type="number"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.PRIORITY')"
              :message="$t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.PRIORITY_HELP')"
            />
            <div class="flex items-center justify-between gap-2 pt-6">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE') }}
              </span>
              <Switch v-model="docForm.is_active" />
            </div>
          </div>
        </div>
      </Dialog>

      <!-- Delete confirmation -->
      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="$t('INTEGRATION_SETTINGS.BOTLAYER.DELETE.TITLE')"
        :description="
          $t('INTEGRATION_SETTINGS.BOTLAYER.DELETE.MESSAGE', {
            name:
              deleteTarget?.record?.display_name ||
              deleteTarget?.record?.title ||
              deleteTarget?.record?.label,
          })
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.BOTLAYER.DELETE.CONFIRM')"
        @confirm="confirmDelete"
      />
    </template>
  </SettingsLayout>
</template>
