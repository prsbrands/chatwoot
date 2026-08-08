<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ModelCombobox from './ModelCombobox.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const personaId = computed(() => route.params.personaId);
const isNew = computed(() => personaId.value === 'new');

const form = ref(null);
const providers = ref([]);
const globalKnowledgeChars = ref(0);
const linkedDocs = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);

const emptyForm = () => ({
  slug: '',
  display_name: '',
  description: '',
  system_prompt: '',
  provider: 'openrouter',
  model: '',
  fallback_provider: '',
  fallback_model: '',
  temperature: 0.6,
  max_tokens: 1200,
  is_active: true,
  keywords: '',
  max_turns: null,
  handoff_rules: {},
});

const providerOptions = computed(() =>
  providers.value
    .filter(provider => provider.is_active)
    .map(provider => ({ value: provider.slug, label: provider.label }))
);

const fallbackProviderOptions = computed(() => [
  { value: '', label: t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SAME_AS_PRIMARY') },
  ...providerOptions.value,
]);

const modelsOf = slug =>
  (providers.value.find(provider => provider.slug === slug)?.models || []).map(
    model => model.id
  );

const promptChars = computed(() => (form.value?.system_prompt || '').length);

// O que o modelo recebe de fato: persona + docs globais + docs vinculados.
const knowledgeChars = computed(
  () =>
    globalKnowledgeChars.value +
    linkedDocs.value.reduce((total, doc) => total + (doc.content || '').length, 0)
);

const totalChars = computed(() => promptChars.value + knowledgeChars.value);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.BOTLAYER.API.ERROR')
  );

const load = async () => {
  try {
    const [personasRes, providersRes, docsRes] = await Promise.all([
      BotlayerAPI.personas(),
      BotlayerAPI.providers(),
      BotlayerAPI.knowledge(),
    ]);
    providers.value = providersRes.data.providers;

    const docs = docsRes.data.docs.filter(doc => doc.is_active);
    globalKnowledgeChars.value = docs
      .filter(doc => doc.is_global)
      .reduce((total, doc) => total + (doc.content || '').length, 0);

    if (isNew.value) {
      form.value = emptyForm();
      linkedDocs.value = [];
      return;
    }

    const persona = personasRes.data.personas.find(
      candidate => candidate.id === personaId.value
    );
    if (!persona) {
      router.replace({ name: 'settings_integrations_botlayer' });
      return;
    }
    linkedDocs.value = docs.filter(
      doc =>
        !doc.is_global &&
        (doc.bot_persona_knowledge || []).some(
          link => link.persona_id === persona.id
        )
    );
    form.value = {
      ...emptyForm(),
      ...persona,
      description: persona.description || '',
      fallback_provider: persona.fallback_provider || '',
      fallback_model: persona.fallback_model || '',
      keywords: (persona.handoff_rules?.keywords || []).join(', '),
      max_turns: persona.handoff_rules?.max_turns || null,
      handoff_rules: persona.handoff_rules || {},
    };
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const canSave = computed(
  () =>
    !isSaving.value &&
    form.value?.display_name &&
    form.value?.slug &&
    form.value?.model
);

const save = async () => {
  isSaving.value = true;
  const data = form.value;
  const payload = {
    slug: data.slug,
    display_name: data.display_name,
    description: data.description,
    system_prompt: data.system_prompt,
    provider: data.provider,
    model: data.model,
    fallback_provider: data.fallback_provider || null,
    fallback_model: data.fallback_model || null,
    temperature: Number(data.temperature),
    max_tokens: Number(data.max_tokens),
    is_active: data.is_active,
    handoff_rules: {
      ...data.handoff_rules,
      keywords: data.keywords
        .split(',')
        .map(keyword => keyword.trim())
        .filter(Boolean),
      max_turns: data.max_turns ? Number(data.max_turns) : null,
    },
  };
  try {
    if (isNew.value) await BotlayerAPI.createPersona(payload);
    else await BotlayerAPI.updatePersona(personaId.value, payload);
    useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
    router.push({ name: 'settings_integrations_botlayer' });
  } catch (error) {
    alertError(error);
  } finally {
    isSaving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <div class="flex h-full w-full min-w-0 flex-1 flex-col overflow-hidden bg-n-surface-1">
    <div
      v-if="isLoading"
      class="flex flex-1 items-center justify-center"
    >
      <Spinner />
    </div>
    <template v-else-if="form">
      <header
        class="flex shrink-0 items-center justify-between gap-4 border-b border-n-weak px-6 py-3"
      >
        <div class="flex items-center gap-3">
          <Button
            slate
            ghost
            sm
            icon="i-lucide-arrow-left"
            @click="router.push({ name: 'settings_integrations_botlayer' })"
          />
          <div>
            <h1 class="text-base font-medium text-n-slate-12">
              {{
                form.display_name ||
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.NEW')
              }}
            </h1>
            <p class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TOTAL_CHARS', {
                prompt: promptChars.toLocaleString(),
                knowledge: knowledgeChars.toLocaleString(),
                total: totalChars.toLocaleString(),
              }) }}
            </p>
          </div>
        </div>
        <Button
          blue
          :label="$t('INTEGRATION_SETTINGS.BOTLAYER.SAVE')"
          :is-loading="isSaving"
          :disabled="!canSave"
          @click="save"
        />
      </header>

      <div class="flex flex-1 gap-6 overflow-hidden p-6">
        <!-- Prompt: ocupa toda a altura disponível -->
        <div class="flex min-w-0 flex-1 flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.PROMPT') }}
          </label>
          <textarea
            v-model="form.system_prompt"
            spellcheck="false"
            class="min-h-0 flex-1 resize-none rounded-lg border border-n-weak bg-n-alpha-black2 p-4 font-mono text-sm leading-relaxed text-n-slate-12 focus:border-n-brand focus:outline-none"
          />
          <p class="text-xs text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.PROMPT_HELP') }}
          </p>
        </div>

        <!-- Configurações -->
        <aside class="flex w-80 shrink-0 flex-col gap-5 overflow-y-auto pr-1">
          <section class="flex flex-col gap-3">
            <h2
              class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
            >
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SECTION_IDENTITY') }}
            </h2>
            <Input
              v-model="form.display_name"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.NAME')"
            />
            <Input
              v-model="form.slug"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SLUG')"
              :disabled="!isNew"
            />
            <Input
              v-model="form.description"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.DESCRIPTION')"
            />
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE') }}
              </span>
              <Switch v-model="form.is_active" />
            </div>
          </section>

          <section class="flex flex-col gap-3">
            <h2
              class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
            >
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SECTION_MODEL') }}
            </h2>
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.PROVIDER') }}
              </span>
              <Select v-model="form.provider" :options="providerOptions" />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MODEL') }}
              </span>
              <ModelCombobox
                v-model="form.model"
                :models="modelsOf(form.provider)"
              />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{
                  $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.FALLBACK_PROVIDER')
                }}
              </span>
              <Select
                v-model="form.fallback_provider"
                :options="fallbackProviderOptions"
              />
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.FALLBACK') }}
              </span>
              <ModelCombobox
                v-model="form.fallback_model"
                :models="modelsOf(form.fallback_provider || form.provider)"
                :placeholder="
                  $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.OPTIONAL')
                "
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <Input
                v-model="form.temperature"
                type="number"
                step="0.1"
                min="0"
                max="2"
                :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TEMPERATURE')"
              />
              <Input
                v-model="form.max_tokens"
                type="number"
                :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MAX_TOKENS')"
              />
            </div>
            <p class="text-xs text-n-slate-11">
              {{
                modelsOf(form.provider).length
                  ? $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MODEL_HELP', {
                      count: modelsOf(form.provider).length,
                    })
                  : $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MODEL_EMPTY')
              }}
            </p>
          </section>

          <section class="flex flex-col gap-3">
            <h2
              class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
            >
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SECTION_HANDOFF') }}
            </h2>
            <Input
              v-model="form.keywords"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.KEYWORDS')"
              :message="
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.KEYWORDS_HELP')
              "
            />
            <Input
              v-model="form.max_turns"
              type="number"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MAX_TURNS')"
            />
          </section>

          <section v-if="linkedDocs.length" class="flex flex-col gap-2">
            <h2
              class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
            >
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.TABS.KNOWLEDGE') }}
            </h2>
            <p
              v-for="doc in linkedDocs"
              :key="doc.id"
              class="truncate text-xs text-n-slate-11"
            >
              {{ doc.title }}
            </p>
          </section>
        </aside>
      </div>
    </template>
  </div>
</template>
