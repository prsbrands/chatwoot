<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const docId = computed(() => route.params.docId);
const isNew = computed(() => docId.value === 'new');

const form = ref(null);
const personas = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);

const contentChars = computed(() => (form.value?.content || '').length);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.BOTLAYER.API.ERROR')
  );

const load = async () => {
  try {
    const [docsRes, personasRes] = await Promise.all([
      BotlayerAPI.knowledge(),
      BotlayerAPI.personas(),
    ]);
    personas.value = personasRes.data.personas;

    if (isNew.value) {
      form.value = {
        slug: '',
        title: '',
        content: '',
        is_global: true,
        priority: 100,
        is_active: true,
        persona_ids: [],
      };
      return;
    }

    const doc = docsRes.data.docs.find(candidate => candidate.id === docId.value);
    if (!doc) {
      router.replace({ name: 'settings_integrations_botlayer' });
      return;
    }
    form.value = {
      ...doc,
      persona_ids: (doc.bot_persona_knowledge || []).map(
        link => link.persona_id
      ),
    };
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const togglePersona = personaId => {
  const ids = form.value.persona_ids;
  form.value.persona_ids = ids.includes(personaId)
    ? ids.filter(id => id !== personaId)
    : [...ids, personaId];
};

const canSave = computed(
  () => !isSaving.value && form.value?.title && form.value?.slug
);

const save = async () => {
  isSaving.value = true;
  const data = form.value;
  const payload = {
    slug: data.slug,
    title: data.title,
    content: data.content,
    is_global: data.is_global,
    priority: Number(data.priority),
    is_active: data.is_active,
    persona_ids: data.persona_ids,
  };
  try {
    if (isNew.value) await BotlayerAPI.createKnowledge(payload);
    else await BotlayerAPI.updateKnowledge(docId.value, payload);
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
  <div class="flex h-full flex-col overflow-hidden">
    <div v-if="isLoading" class="flex flex-1 items-center justify-center">
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
                form.title || $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.NEW')
              }}
            </h1>
            <p class="text-xs text-n-slate-11">
              {{ contentChars.toLocaleString() }}
              {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.CHARS') }}
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
        <div class="flex min-w-0 flex-1 flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.CONTENT') }}
          </label>
          <textarea
            v-model="form.content"
            spellcheck="false"
            class="min-h-0 flex-1 resize-none rounded-lg border border-n-weak bg-n-alpha-black2 p-4 font-mono text-sm leading-relaxed text-n-slate-12 focus:border-n-brand focus:outline-none"
          />
          <p class="text-xs text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.CONTENT_HELP') }}
          </p>
        </div>

        <aside class="flex w-80 shrink-0 flex-col gap-5 overflow-y-auto pr-1">
          <section class="flex flex-col gap-3">
            <Input
              v-model="form.title"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.TITLE')"
            />
            <Input
              v-model="form.slug"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.PERSONAS.SLUG')"
              :disabled="!isNew"
            />
            <Input
              v-model="form.priority"
              type="number"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.PRIORITY')"
              :message="
                $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.PRIORITY_HELP')
              "
            />
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm text-n-slate-12">
                {{ $t('INTEGRATION_SETTINGS.BOTLAYER.ACTIVE') }}
              </span>
              <Switch v-model="form.is_active" />
            </div>
          </section>

          <section class="flex flex-col gap-3">
            <div class="flex items-center justify-between gap-2">
              <span class="text-sm text-n-slate-12">
                {{
                  $t('INTEGRATION_SETTINGS.BOTLAYER.KNOWLEDGE.GLOBAL_TOGGLE')
                }}
              </span>
              <Switch v-model="form.is_global" />
            </div>
            <template v-if="!form.is_global">
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
                  :checked="form.persona_ids.includes(persona.id)"
                  @change="togglePersona(persona.id)"
                />
                {{ persona.display_name }} ({{ persona.slug }})
              </label>
            </template>
          </section>
        </aside>
      </div>
    </template>
  </div>
</template>
