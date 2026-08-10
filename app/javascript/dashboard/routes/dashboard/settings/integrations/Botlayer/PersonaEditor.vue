<script setup>
import { computed, onMounted, ref, watch } from 'vue';
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
  stt_provider: '',
  stt_model: '',
  tts_provider: '',
  tts_voice_id: '',
  tts_model: '',
  voice_language: '',
  stt_language: '',
  voice_first_message: '',
  voice_greeting_delay_ms: 300,
  voice_endpoint_ms: 600,
  voice_interruptible: true,
  voice_wait_for_complete_turn: true,
  voice_interrupt_min_words: 0,
  voice_eot_threshold: 0.8,
});

// Um fornecedor só aparece onde a chave dele foi autorizada a servir.
const providersServing = kind =>
  providers.value
    .filter(
      provider =>
        provider.is_active && (provider.kinds || ['llm']).includes(kind)
    )
    .map(provider => ({ value: provider.slug, label: provider.label }));

const providerOptions = computed(() => providersServing('llm'));

const sttProviderOptions = computed(() => [
  { value: '', label: t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_NONE') },
  ...providersServing('stt'),
]);

const ttsProviderOptions = computed(() => [
  { value: '', label: t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_NONE') },
  ...providersServing('tts'),
]);

// Cada fornecedor tem um modelo que é a escolha certa por padrão. Deixar isso
// como placeholder cinza fazia o campo parecer preenchido — e um modelo vazio
// não falha: cai no default do fornecedor, calado.
const DEFAULT_MODELS = {
  stt: {
    deepgram: 'nova-3',
    openrouter: 'deepgram/nova-3',
    openai: 'gpt-4o-transcribe',
    groq: 'whisper-large-v3',
  },
  tts: {
    elevenlabs: 'eleven_multilingual_v2',
    openai: 'tts-1',
  },
};

// Só estes aceitam idioma forçado. O multilingual_v2 deduz do texto — e é por
// isso que ele atende em vários idiomas com a mesma voz.
const MODELS_ACCEPTING_LANGUAGE = ['eleven_flash_v2_5', 'eleven_turbo_v2_5'];

const VOICE_MODELS = {
  elevenlabs: [
    'eleven_multilingual_v2',
    'eleven_flash_v2_5',
    'eleven_turbo_v2_5',
  ],
};

const LANGUAGES = ['es', 'pt-BR', 'en'];

watch(
  () => form.value?.stt_provider,
  slug => {
    if (slug && !form.value.stt_model) {
      form.value.stt_model = DEFAULT_MODELS.stt[slug] || '';
    }
  }
);

watch(
  () => form.value?.tts_provider,
  slug => {
    if (slug && !form.value.tts_model) {
      form.value.tts_model = DEFAULT_MODELS.tts[slug] || '';
    }
  }
);

const voiceModelOptions = computed(() =>
  (VOICE_MODELS[form.value?.tts_provider] || []).map(id => ({
    value: id,
    label: t(`INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TTS_MODELS.${id}`),
  }))
);

// O que o transcritor escuta. 'multi' deixa o Deepgram trocar de idioma no meio
// da chamada, que é o que uma linha atendendo três países precisa.
const sttLanguageOptions = computed(() => [
  {
    value: 'multi',
    label: t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.LANG_MULTI'),
  },
  ...LANGUAGES.map(code => ({ value: code, label: code })),
]);

// O que a voz fala. Em branco significa "siga o texto", que é o único modo do
// multilingual_v2 e quase sempre o certo: o modelo já responde no idioma de
// quem ligou.
const ttsLanguageOptions = computed(() => [
  {
    value: '',
    label: t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.LANG_FOLLOW'),
  },
  ...LANGUAGES.map(code => ({ value: code, label: code })),
]);

// O Flux traz a máquina de turnos dentro do transcritor, e os campos que
// controlam a nossa não chegam nele: `End of turn`, `Wait until the caller
// finishes` e `Words needed to interrupt` alimentam o VAD do Silero e as
// estratégias de turno, que a rota Flux contorna inteira. Ficavam na tela
// parecendo configurados. Quem manda ali é o limiar de confiança.
const usesFlux = computed(() =>
  String(form.value?.stt_model || '').startsWith('flux')
);

// Idioma travado num modelo que não aceita idioma é ajuste que não acontece.
const languageIgnored = computed(
  () =>
    Boolean(form.value?.voice_language) &&
    form.value?.tts_provider === 'elevenlabs' &&
    !MODELS_ACCEPTING_LANGUAGE.includes(form.value?.tts_model)
);

const voiceGaps = computed(() => {
  const data = form.value;
  if (!data) return [];
  const gaps = [];
  if (!data.stt_provider) gaps.push(t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.STT_PROVIDER'));
  if (!data.tts_provider) gaps.push(t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TTS_PROVIDER'));
  if (data.tts_provider && !data.tts_voice_id) {
    gaps.push(t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_ID'));
  }
  // Só a transcrição precisa saber o idioma de antemão; a voz pode seguir o
  // texto, então em branco ali não é lacuna.
  if (!data.stt_language) gaps.push(t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.STT_LANGUAGE'));
  // Quem atende telefone diz sempre a mesma coisa ao atender. Deixar o modelo
  // improvisar a abertura muda o texto a cada chamada e custa o tempo de uma
  // ida ao modelo antes da primeira palavra.
  if (!data.voice_first_message) {
    gaps.push(t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.FIRST_MESSAGE'));
  }
  return gaps;
});

const voiceReady = computed(() => voiceGaps.value.length === 0);

// Prompt longo pesa na conversa, não no relógio: medimos 23,9 KB contra 11 KB
// no mesmo modelo e o tempo até o primeiro byte não mudou (a OpenAI cacheia o
// prefixo). O que ele custa é adesão — num prompt grande só a lista final é
// obedecida de verdade — e risco de retry.
const promptIsHeavyForVoice = computed(
  () => voiceReady.value && totalChars.value > 8000
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
      stt_provider: persona.stt_provider || '',
      stt_model: persona.stt_model || '',
      tts_provider: persona.tts_provider || '',
      tts_voice_id: persona.tts_voice_id || '',
      tts_model: persona.tts_model || '',
      voice_language: persona.voice_language || '',
      stt_language: persona.stt_language || '',
      voice_first_message: persona.voice_first_message || '',
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
    stt_provider: data.stt_provider || null,
    stt_model: data.stt_model || null,
    tts_provider: data.tts_provider || null,
    tts_voice_id: data.tts_voice_id || null,
    tts_model: data.tts_model || null,
    voice_language: data.voice_language || null,
    stt_language: data.stt_language || null,
    voice_first_message: data.voice_first_message || null,
    voice_greeting_delay_ms: Number(data.voice_greeting_delay_ms),
    voice_endpoint_ms: Number(data.voice_endpoint_ms),
    voice_interruptible: data.voice_interruptible,
    voice_wait_for_complete_turn: data.voice_wait_for_complete_turn,
    voice_interrupt_min_words: Number(data.voice_interrupt_min_words) || 0,
    voice_eot_threshold: Number(data.voice_eot_threshold) || 0.8,
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

          <section class="flex flex-col gap-3">
            <div class="flex items-center justify-between gap-2">
              <h2
                class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
              >
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SECTION_VOICE') }}
              </h2>
              <span
                class="rounded px-1.5 py-0.5 text-xs font-medium"
                :class="
                  voiceReady
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{
                  voiceReady
                    ? $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_READY')
                    : $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_OFF')
                }}
              </span>
            </div>
            <p class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_HELP') }}
            </p>
            <p v-if="voiceGaps.length" class="text-xs text-n-amber-11">
              {{
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_GAPS', {
                  fields: voiceGaps.join(', '),
                })
              }}
            </p>
            <!-- Ligar o bot num número não passa pela aba Channels, que é o
                 mapa de inboxes de mensagem. -->
            <p v-else class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_WHERE') }}
            </p>
            <p v-if="promptIsHeavyForVoice" class="text-xs text-n-amber-11">
              {{
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_PROMPT_HEAVY', {
                  total: totalChars.toLocaleString(),
                })
              }}
            </p>

            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{
                  $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.STT_PROVIDER')
                }}
              </span>
              <Select
                v-model="form.stt_provider"
                :options="sttProviderOptions"
              />
            </div>
            <template v-if="form.stt_provider">
              <Input
                v-model="form.stt_model"
                :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.STT_MODEL')"
              />
              <div class="flex flex-col gap-1">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.STT_LANGUAGE')
                  }}
                </span>
                <Select
                  v-model="form.stt_language"
                  :options="sttLanguageOptions"
                />
              </div>
            </template>

            <div class="flex flex-col gap-1">
              <span class="text-sm text-n-slate-12">
                {{
                  $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TTS_PROVIDER')
                }}
              </span>
              <Select
                v-model="form.tts_provider"
                :options="ttsProviderOptions"
              />
            </div>
            <template v-if="form.tts_provider">
              <Input
                v-model="form.tts_voice_id"
                :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_ID')"
                :message="
                  $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_ID_HELP')
                "
              />
              <div class="flex flex-col gap-1">
                <span class="text-sm text-n-slate-12">
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TTS_MODEL') }}
                </span>
                <Select
                  v-if="voiceModelOptions.length"
                  v-model="form.tts_model"
                  :options="voiceModelOptions"
                />
                <Input v-else v-model="form.tts_model" />
              </div>
              <div class="flex flex-col gap-1">
                <span class="text-sm text-n-slate-12">
                  {{
                    $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.VOICE_LANGUAGE')
                  }}
                </span>
                <Select
                  v-model="form.voice_language"
                  :options="ttsLanguageOptions"
                />
                <span
                  v-if="languageIgnored"
                  class="text-xs text-n-amber-11"
                >
                  {{
                    $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.LANG_IGNORED', {
                      model: form.tts_model,
                    })
                  }}
                </span>
              </div>
            </template>

            <Input
              v-if="usesFlux"
              v-model="form.voice_eot_threshold"
              type="number"
              step="0.05"
              min="0.5"
              max="0.95"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.EOT_THRESHOLD')"
              :message="
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.EOT_THRESHOLD_HELP')
              "
            />
            <Input
              v-else
              v-model="form.voice_endpoint_ms"
              type="number"
              step="50"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.ENDPOINT_MS')"
            />
            <Input
              v-model="form.voice_greeting_delay_ms"
              type="number"
              step="50"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.GREETING_MS')"
              :message="
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.TIMING_HELP')
              "
            />
            <Input
              v-model="form.voice_first_message"
              :label="
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.FIRST_MESSAGE')
              "
              :message="
                $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.FIRST_MESSAGE_HELP')
              "
            />
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.INTERRUPTIBLE') }}
              </span>
              <Switch v-model="form.voice_interruptible" />
            </div>
            <div v-if="!usesFlux" class="flex flex-col gap-1">
              <div class="flex items-center justify-between gap-2">
                <span class="text-sm text-n-slate-12">
                  {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.WAIT_TURN') }}
                </span>
                <Switch v-model="form.voice_wait_for_complete_turn" />
              </div>
              <span class="text-xs text-n-slate-11">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.WAIT_TURN_HELP') }}
              </span>
            </div>
            <Input
              v-if="!usesFlux && form.voice_interruptible"
              v-model="form.voice_interrupt_min_words"
              type="number"
              min="0"
              max="5"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MIN_WORDS')"
              :message="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.MIN_WORDS_HELP')"
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
