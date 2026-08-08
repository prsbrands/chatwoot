<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
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
const router = useRouter();
const getters = useStoreGetters();

const TABS = ['personas', 'knowledge', 'channels'];
const activeTab = ref('personas');

const personas = ref([]);
const docs = ref([]);
const routes = ref([]);
const providers = ref([]);
const isLoading = ref(true);

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

// --- Personas / Knowledge: editados em página dedicada ---

const openPersonaEditor = persona =>
  router.push({
    name: 'settings_integrations_botlayer_persona',
    params: { personaId: persona?.id || 'new' },
  });

const openDocEditor = doc =>
  router.push({
    name: 'settings_integrations_botlayer_knowledge',
    params: { docId: doc?.id || 'new' },
  });

// --- Delete (personas + docs) ---

const openDeleteDialog = (kind, record) => {
  deleteTarget.value = { kind, record };
  deleteDialogRef.value.open();
};

const confirmDelete = async () => {
  const { kind, record } = deleteTarget.value;
  try {
    if (kind === 'persona') await BotlayerAPI.deletePersona(record.id);
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
      >
        <template #actions>
          <Button
            slate
            faded
            sm
            icon="i-lucide-key-round"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS_LINK')"
            @click="
              router.push({ name: 'settings_integrations_ai_providers' })
            "
          />
        </template>
      </BaseSettingsHeader>
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
              @click="openPersonaEditor(null)"
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
                    @click="openPersonaEditor(persona)"
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
              @click="openDocEditor(null)"
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
                  @click="openDocEditor(doc)"
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

      </div>

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
