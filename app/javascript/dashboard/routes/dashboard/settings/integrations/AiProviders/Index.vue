<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();

const API_STYLES = [
  { value: 'openai', label: 'OpenAI-compatible' },
  { value: 'anthropic', label: 'Anthropic Messages' },
  { value: 'elevenlabs', label: 'ElevenLabs' },
];

// O que cada chave serve. Um mesmo fornecedor pode servir mais de uma coisa — a
// conta de OpenRouter faz o LLM e a transcrição (Deepgram nova-3), a de OpenAI
// faz as três — e é por isso que é lista, não escolha única: a chave é o que não
// se quer duplicar.
const KINDS = ['llm', 'stt', 'tts'];

// Atalhos para os fornecedores mais comuns: preenchem URL, formato e para que
// servem, restando só a chave. Base URLs conforme a documentação de cada API.
const PRESETS = [
  { slug: 'openrouter', label: 'OpenRouter', base_url: 'https://openrouter.ai/api/v1', api_style: 'openai', kinds: ['llm', 'stt'] },
  { slug: 'elevenlabs', label: 'ElevenLabs', base_url: 'https://api.elevenlabs.io/v1', api_style: 'elevenlabs', kinds: ['tts'] },
  { slug: 'anthropic', label: 'Anthropic', base_url: 'https://api.anthropic.com/v1', api_style: 'anthropic', kinds: ['llm'] },
  { slug: 'openai', label: 'OpenAI', base_url: 'https://api.openai.com/v1', api_style: 'openai', kinds: ['llm', 'stt', 'tts'] },
  { slug: 'groq', label: 'Groq', base_url: 'https://api.groq.com/openai/v1', api_style: 'openai', kinds: ['llm', 'stt'] },
  { slug: 'deepseek', label: 'DeepSeek', base_url: 'https://api.deepseek.com/v1', api_style: 'openai', kinds: ['llm'] },
  { slug: 'mistral', label: 'Mistral', base_url: 'https://api.mistral.ai/v1', api_style: 'openai', kinds: ['llm'] },
];

const providers = ref([]);
const isLoading = ref(true);
const dialogRef = ref(null);
const deleteDialogRef = ref(null);
const form = ref({});
const isNew = ref(false);
const isSaving = ref(false);
const syncingId = ref(null);
const toDelete = ref(null);

const availablePresets = computed(() =>
  PRESETS.filter(
    preset => !providers.value.some(provider => provider.slug === preset.slug)
  )
);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.BOTLAYER.API.ERROR')
  );

const fetchProviders = async () => {
  try {
    const { data } = await BotlayerAPI.providers();
    providers.value = data.providers;
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const openDialog = (provider, preset) => {
  isNew.value = !provider;
  form.value = provider
    ? {
        id: provider.id,
        slug: provider.slug,
        label: provider.label,
        base_url: provider.base_url,
        api_style: provider.api_style,
        kinds: [...(provider.kinds || ['llm'])],
        api_key: '',
        has_key: Boolean(provider.api_key),
        is_active: provider.is_active,
      }
    : {
        slug: preset?.slug || '',
        label: preset?.label || '',
        base_url: preset?.base_url || '',
        api_style: preset?.api_style || 'openai',
        kinds: [...(preset?.kinds || ['llm'])],
        api_key: '',
        has_key: false,
        is_active: true,
      };
  dialogRef.value.open();
};

const toggleKind = kind => {
  const { kinds } = form.value;
  const at = kinds.indexOf(kind);
  if (at === -1) kinds.push(kind);
  else kinds.splice(at, 1);
};

// Sincronizar catálogo é conversa de LLM: um fornecedor de voz não tem /models
// para listar.
const servesModels = provider => (provider.kinds || ['llm']).includes('llm');

const save = async () => {
  isSaving.value = true;
  const data = form.value;
  const payload = {
    slug: data.slug,
    label: data.label,
    base_url: data.base_url,
    api_style: data.api_style,
    kinds: data.kinds,
    api_key: data.api_key,
    is_active: data.is_active,
  };
  try {
    if (isNew.value) await BotlayerAPI.createProvider(payload);
    else await BotlayerAPI.updateProvider(data.id, payload);
    dialogRef.value.close();
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
    fetchProviders();
  } catch (error) {
    alertError(error);
  } finally {
    isSaving.value = false;
  }
};

const syncModels = async provider => {
  syncingId.value = provider.id;
  try {
    const { data } = await BotlayerAPI.syncModels(provider.id);
    useAlert(
      t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.SYNCED', {
        count: (data.models || []).length,
      })
    );
    fetchProviders();
  } catch (error) {
    alertError(error);
  } finally {
    syncingId.value = null;
  }
};

const confirmDelete = async () => {
  try {
    await BotlayerAPI.deleteProvider(toDelete.value.id);
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.DELETED'));
    fetchProviders();
  } catch (error) {
    alertError(error);
  } finally {
    deleteDialogRef.value.close();
  }
};

onMounted(fetchProviders);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.HEADER')"
        :description="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.DESCRIPTION')"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      >
        <template #actions>
          <Button
            blue
            sm
            icon="i-lucide-circle-plus"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.NEW')"
            @click="openDialog(null, null)"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="flex w-full flex-col gap-6">
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          <div
            v-for="provider in providers"
            :key="provider.id"
            class="flex flex-col gap-3 rounded-xl bg-n-card p-4 outline outline-1 outline-n-container"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="font-medium text-n-slate-12">{{ provider.label }}</p>
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
            <div class="flex flex-wrap gap-1">
              <span
                v-for="kind in provider.kinds || ['llm']"
                :key="kind"
                class="rounded bg-n-alpha-2 px-1.5 py-0.5 text-xs font-medium uppercase text-n-slate-11"
              >
                {{ $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.KIND.${kind}`) }}
              </span>
            </div>
            <div class="flex items-center justify-between gap-2">
              <span class="text-xs text-n-slate-10">
                <template v-if="servesModels(provider)">
                  {{
                    $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.MODEL_COUNT', {
                      count: (provider.models || []).length,
                    })
                  }}
                  ·
                </template>
                {{ provider.api_style }}
              </span>
              <div class="flex gap-1">
                <Button
                  v-if="servesModels(provider)"
                  sm
                  slate
                  ghost
                  icon="i-lucide-refresh-cw"
                  :is-loading="syncingId === provider.id"
                  :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.SYNC')"
                  @click="syncModels(provider)"
                />
                <Button
                  sm
                  slate
                  ghost
                  icon="i-lucide-pencil"
                  @click="openDialog(provider, null)"
                />
                <Button
                  sm
                  ruby
                  ghost
                  icon="i-lucide-trash-2"
                  @click="
                    toDelete = provider;
                    deleteDialogRef.open();
                  "
                />
              </div>
            </div>
          </div>
        </div>

        <div v-if="availablePresets.length" class="flex flex-col gap-2">
          <p class="text-sm text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.QUICK_ADD') }}
          </p>
          <div class="flex flex-wrap gap-2">
            <Button
              v-for="preset in availablePresets"
              :key="preset.slug"
              sm
              slate
              outline
              icon="i-lucide-plus"
              :label="preset.label"
              @click="openDialog(null, preset)"
            />
          </div>
        </div>

        <p class="text-xs text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.CHANNELS_NOTE') }}
        </p>
      </div>

      <Dialog
        ref="dialogRef"
        :title="
          isNew
            ? $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.NEW')
            : $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.EDIT')
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.BOTLAYER.SAVE')"
        :is-loading="isSaving"
        :disable-confirm-button="
          isSaving ||
          !form.label ||
          !form.slug ||
          !form.base_url ||
          !form.kinds?.length
        "
        @confirm="save"
      >
        <div class="flex flex-col gap-4">
          <div class="grid grid-cols-2 gap-3">
            <Input
              v-model="form.label"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.LABEL')"
              placeholder="Groq"
            />
            <Input
              v-model="form.slug"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SLUG')"
              :disabled="!isNew"
              placeholder="groq"
            />
          </div>
          <Input
            v-model="form.base_url"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.BASE_URL')"
            placeholder="https://api.groq.com/openai/v1"
            :message="
              $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.BASE_URL_HELP')
            "
          />
          <div class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.API_STYLE') }}
            </span>
            <Select v-model="form.api_style" :options="API_STYLES" />
          </div>
          <div class="flex flex-col gap-2">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.KINDS') }}
            </span>
            <div class="flex gap-4">
              <label
                v-for="kind in KINDS"
                :key="kind"
                class="flex cursor-pointer items-center gap-2"
              >
                <Checkbox
                  :model-value="form.kinds?.includes(kind)"
                  @change="toggleKind(kind)"
                />
                <span class="text-sm text-n-slate-12">
                  {{ $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.KIND.${kind}`) }}
                </span>
              </label>
            </div>
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.KINDS_HELP') }}
            </span>
          </div>
          <Input
            v-model="form.api_key"
            type="password"
            :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.API_KEY')"
            :placeholder="
              form.has_key
                ? $t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.KEY_KEEP')
                : 'sk-...'
            "
            :message="$t('INTEGRATION_SETTINGS.BOTLAYER.PROVIDERS.API_KEY_HELP')"
          />
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE') }}
            </span>
            <Switch v-model="form.is_active" />
          </div>
        </div>
      </Dialog>

      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="$t('INTEGRATION_SETTINGS.BOTLAYER.DELETE.TITLE')"
        :description="
          $t('INTEGRATION_SETTINGS.BOTLAYER.DELETE.MESSAGE', {
            name: toDelete?.label,
          })
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.BOTLAYER.DELETE.CONFIRM')"
        @confirm="confirmDelete"
      />
    </template>
  </SettingsLayout>
</template>
