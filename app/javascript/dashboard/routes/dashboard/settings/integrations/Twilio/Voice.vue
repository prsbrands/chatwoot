<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import TwilioAPI from 'dashboard/api/integrations/twilio';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  numbers: { type: Array, default: () => [] },
});

const { t } = useI18n();

const domains = ref([]);
const credentials = ref([]);
const routes = ref([]);
const calls = ref([]);
const alerts = ref([]);
const selectedDomain = ref(null);
const isBusy = ref(false);
const newSubdomain = ref('');
const newUsername = ref('');
const issuedCredential = ref(null);
const credentialDialogRef = ref(null);

const personas = ref([]);

const routeForm = ref({
  phone_number: '',
  destination_type: 'sip',
  destination: '',
  ring_timeout: 20,
  answer_mode: 'human',
  no_answer_action: 'hangup',
  bot_persona_slug: '',
});

const managedDomain = computed(() => domains.value.find(d => d.managed));
const externalDomains = computed(() => domains.value.filter(d => !d.managed));

const voiceNumbers = computed(() =>
  props.numbers
    .filter(number => number.capabilities.voice)
    .map(number => ({ value: number.phone_number, label: number.phone_number }))
);

const destinationTypes = computed(() => [
  { value: 'sip', label: t('INTEGRATION_SETTINGS.TWILIO.VOICE.TYPE_SIP') },
  { value: 'pstn', label: t('INTEGRATION_SETTINGS.TWILIO.VOICE.TYPE_PSTN') },
]);

const answerModes = computed(() => [
  { value: 'human', label: t('INTEGRATION_SETTINGS.TWILIO.VOICE.MODE_HUMAN') },
  { value: 'bot', label: t('INTEGRATION_SETTINGS.TWILIO.VOICE.MODE_BOT') },
]);

const noAnswerActions = computed(() => [
  {
    value: 'hangup',
    label: t('INTEGRATION_SETTINGS.TWILIO.VOICE.NO_ANSWER_HANGUP'),
  },
  { value: 'bot', label: t('INTEGRATION_SETTINGS.TWILIO.VOICE.NO_ANSWER_BOT') },
]);

// Só entram personas que têm as três pontas de voz configuradas: escolher uma
// persona de texto aqui daria uma chamada muda.
const voicePersonas = computed(() =>
  personas.value
    .filter(
      persona =>
        persona.is_active &&
        persona.stt_provider &&
        persona.tts_provider &&
        persona.tts_voice_id
    )
    .map(persona => ({ value: persona.slug, label: persona.display_name }))
);

const humanAnswers = computed(() => routeForm.value.answer_mode === 'human');

const needsPersona = computed(
  () =>
    routeForm.value.answer_mode === 'bot' ||
    routeForm.value.no_answer_action === 'bot'
);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.TWILIO.API.ERROR')
  );

const fetchAll = async () => {
  try {
    const [domainsRes, routesRes] = await Promise.all([
      TwilioAPI.sipDomains(),
      TwilioAPI.voiceRoutes(),
    ]);
    domains.value = domainsRes.data.domains;
    routes.value = routesRes.data.routes;
    calls.value = routesRes.data.calls;
    if (managedDomain.value) await fetchCredentials();
  } catch (error) {
    alertError(error);
  }
};

// Carregado à parte e sem barulho: cada alerta exige um fetch individual no
// Twilio para saber a causa de verdade, e uma tela de configuração não pode
// ficar esperando — nem quebrar — porque a API deles está lenta ou fora.
const fetchAlerts = async () => {
  try {
    const { data } = await TwilioAPI.alerts();
    alerts.value = data.alerts;
  } catch {
    alerts.value = [];
  }
};

// A camada de bots pode estar desligada nesta conta (feature flag). Sem ela a
// aba segue funcionando para atendimento humano, só não oferece o bot.
const fetchPersonas = async () => {
  try {
    const { data } = await BotlayerAPI.personas();
    personas.value = data.personas;
  } catch {
    personas.value = [];
  }
};

const fetchCredentials = async () => {
  try {
    const { data } = await TwilioAPI.sipCredentials(managedDomain.value.sid);
    credentials.value = data.credentials;
  } catch (error) {
    alertError(error);
  }
};

const createDomain = async () => {
  if (!newSubdomain.value.trim()) return;
  isBusy.value = true;
  try {
    await TwilioAPI.createSipDomain(newSubdomain.value.trim());
    newSubdomain.value = '';
    useAlert(t('INTEGRATION_SETTINGS.TWILIO.VOICE.DOMAIN_CREATED'));
    await fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    isBusy.value = false;
  }
};

// A senha só existe nesta resposta: o Twilio guarda o hash e nós não guardamos
// nada. Por isso ela abre num diálogo próprio, para ser copiada agora.
const createCredential = async () => {
  if (!newUsername.value.trim()) return;
  isBusy.value = true;
  try {
    const { data } = await TwilioAPI.createSipCredential(
      managedDomain.value.sid,
      newUsername.value.trim()
    );
    issuedCredential.value = {
      ...data,
      domain: managedDomain.value.domain_name,
    };
    newUsername.value = '';
    credentialDialogRef.value.open();
    await fetchCredentials();
  } catch (error) {
    alertError(error);
  } finally {
    isBusy.value = false;
  }
};

const removeCredential = async credential => {
  try {
    await TwilioAPI.deleteSipCredential(
      managedDomain.value.sid,
      credential.sid
    );
    await fetchCredentials();
  } catch (error) {
    alertError(error);
  }
};

const canSaveRoute = computed(() => {
  const form = routeForm.value;
  if (!form.phone_number) return false;
  if (needsPersona.value && !form.bot_persona_slug) return false;
  if (!humanAnswers.value) return true;
  return Boolean(form.destination.trim()) && form.ring_timeout > 4;
});

const saveRoute = async () => {
  if (!canSaveRoute.value) return;
  isBusy.value = true;
  try {
    await TwilioAPI.saveVoiceRoute(routeForm.value);
    useAlert(t('INTEGRATION_SETTINGS.TWILIO.VOICE.ROUTE_SAVED'));
    routeForm.value.destination = '';
    await fetchAll();
  } catch (error) {
    alertError(error);
  } finally {
    isBusy.value = false;
  }
};

const removeRoute = async route => {
  try {
    await TwilioAPI.deleteVoiceRoute(route.id);
    await fetchAll();
  } catch (error) {
    alertError(error);
  }
};

const copyCredential = async () => {
  const { username, password, domain } = issuedCredential.value;
  await copyTextToClipboard(`${username}@${domain} / ${password}`);
  useAlert(t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREDENTIAL_COPIED'));
};

onMounted(() => {
  fetchAll();
  fetchPersonas();
  fetchAlerts();
});
</script>

<template>
  <div class="flex flex-col gap-8">
    <!-- Domínio SIP -->
    <div class="flex flex-col gap-3">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.SIP_TITLE') }}
      </p>
      <p class="text-sm text-n-slate-11">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.SIP_HELP') }}
      </p>

      <div
        v-if="managedDomain"
        class="rounded-xl bg-n-card p-4 outline outline-1 outline-n-container"
      >
        <p class="font-mono text-sm text-n-slate-12">
          {{ managedDomain.domain_name }}
        </p>
      </div>
      <div v-else class="flex items-end gap-2">
        <Input
          v-model="newSubdomain"
          class="flex-1"
          :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.SUBDOMAIN')"
          :message="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.SUBDOMAIN_HELP')"
          placeholder="cortexgen-prs"
        />
        <Button
          blue
          :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREATE_DOMAIN')"
          :is-loading="isBusy"
          :disabled="!newSubdomain.trim()"
          @click="createDomain"
        />
      </div>

      <div v-if="externalDomains.length" class="flex flex-col gap-1">
        <p class="text-xs text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.EXTERNAL_DOMAINS') }}
        </p>
        <div
          v-for="domain in externalDomains"
          :key="domain.sid"
          class="flex items-center justify-between rounded-lg bg-n-alpha-1 px-3 py-2"
        >
          <span class="font-mono text-xs text-n-slate-11">
            {{ domain.domain_name }}
          </span>
          <span class="text-xs text-n-slate-10">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.EXTERNAL_TAG') }}
          </span>
        </div>
      </div>
    </div>

    <!-- Credenciais dos softphones -->
    <div v-if="managedDomain" class="flex flex-col gap-3">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREDENTIALS_TITLE') }}
      </p>
      <p class="text-sm text-n-slate-11">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREDENTIALS_HELP') }}
      </p>
      <div class="flex items-end gap-2">
        <Input
          v-model="newUsername"
          class="flex-1"
          :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.USERNAME')"
          placeholder="paulo"
        />
        <Button
          blue
          faded
          :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREATE_CREDENTIAL')"
          :is-loading="isBusy"
          :disabled="!newUsername.trim()"
          @click="createCredential"
        />
      </div>
      <div
        v-for="credential in credentials"
        :key="credential.sid"
        class="flex items-center justify-between rounded-lg bg-n-alpha-1 px-3 py-2"
      >
        <span class="font-mono text-sm text-n-slate-12">
          {{ credential.username }}@{{ managedDomain.domain_name }}
        </span>
        <Button
          sm
          ruby
          ghost
          icon="i-lucide-trash-2"
          @click="removeCredential(credential)"
        />
      </div>
    </div>

    <!-- Roteamento -->
    <div v-if="managedDomain" class="flex flex-col gap-3">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.ROUTING_TITLE') }}
      </p>
      <p class="text-sm text-n-slate-11">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.ROUTING_HELP') }}
      </p>
      <div class="flex flex-wrap items-end gap-2">
        <div class="flex flex-col gap-1">
          <label class="text-sm text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.NUMBER') }}
          </label>
          <Select
            v-model="routeForm.phone_number"
            :options="voiceNumbers"
            :placeholder="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.PICK_NUMBER')"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.ANSWER_MODE') }}
          </label>
          <Select v-model="routeForm.answer_mode" :options="answerModes" />
        </div>
        <template v-if="humanAnswers">
          <div class="flex flex-col gap-1">
            <label class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.DESTINATION_TYPE') }}
            </label>
            <Select
              v-model="routeForm.destination_type"
              :options="destinationTypes"
            />
          </div>
          <Input
            v-model="routeForm.destination"
            class="flex-1 min-w-48"
            :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.DESTINATION')"
            :placeholder="
              routeForm.destination_type === 'sip'
                ? `paulo@${managedDomain.domain_name}`
                : '+15551234567'
            "
          />
          <Input
            v-model="routeForm.ring_timeout"
            type="number"
            class="w-28"
            :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.TIMEOUT')"
          />
          <div class="flex flex-col gap-1">
            <label class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.NO_ANSWER') }}
            </label>
            <Select
              v-model="routeForm.no_answer_action"
              :options="noAnswerActions"
            />
          </div>
        </template>
        <div v-if="needsPersona" class="flex flex-col gap-1">
          <label class="text-sm text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.PERSONA') }}
          </label>
          <Select
            v-model="routeForm.bot_persona_slug"
            :options="voicePersonas"
            :placeholder="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.PICK_PERSONA')"
          />
        </div>
        <Button
          blue
          :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.SAVE_ROUTE')"
          :is-loading="isBusy"
          :disabled="!canSaveRoute"
          @click="saveRoute"
        />
      </div>

      <div
        v-for="route in routes"
        :key="route.id"
        class="flex items-center justify-between rounded-lg bg-n-alpha-1 px-3 py-2 text-sm"
      >
        <span class="text-n-slate-12">
          {{ route.phone_number }} →
          <template v-if="route.answer_mode === 'bot'">
            <span class="font-mono">{{ route.bot_persona_slug }}</span>
            <span class="text-n-slate-10">
              ({{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.MODE_BOT') }})
            </span>
          </template>
          <template v-else>
            <span class="font-mono">{{ route.destination }}</span>
            <span class="text-n-slate-10">
              ({{ route.destination_type.toUpperCase() }},
              {{ route.ring_timeout }}s →
              {{
                route.no_answer_action === 'bot'
                  ? route.bot_persona_slug
                  : $t('INTEGRATION_SETTINGS.TWILIO.VOICE.NO_ANSWER_HANGUP')
              }})
            </span>
          </template>
        </span>
        <Button
          sm
          ruby
          ghost
          icon="i-lucide-trash-2"
          @click="removeRoute(route)"
        />
      </div>
    </div>

    <!-- O que o Twilio tentou e não conseguiu.
         Uma chamada que morre antes de alcançar o nosso webhook não deixa
         rastro em log nenhum daqui: nem Rails, nem nginx. Sem esta lista, a
         única forma de saber é desconfiar e entrar no console do Twilio. -->
    <div v-if="alerts.length" class="flex flex-col gap-2">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.ALERTS_TITLE') }}
      </p>
      <p class="text-xs text-n-slate-11">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.ALERTS_HELP') }}
      </p>
      <div
        v-for="alert in alerts"
        :key="alert.sid"
        class="flex flex-col gap-1 rounded-lg bg-n-ruby-2 px-3 py-2 text-sm"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="font-medium text-n-ruby-11">
            {{ alert.request_method }} {{ alert.request_url }}
          </span>
          <a
            :href="alert.docs_url"
            target="_blank"
            rel="noopener noreferrer"
            class="shrink-0 font-mono text-xs text-n-ruby-11 underline"
          >
            {{ alert.error_code }}
          </a>
        </div>
        <!-- A causa vem do corpo da resposta, não do resumo do alerta: o resumo
             chama tudo de "Got HTTP 502" mesmo quando foi falha de DNS. -->
        <span v-if="alert.cause" class="text-xs text-n-slate-11">
          {{ alert.cause }}
        </span>
        <span class="text-xs text-n-slate-10">
          {{ new Date(alert.created_at).toLocaleString() }}
        </span>
      </div>
    </div>

    <!-- Chamadas -->
    <div v-if="calls.length" class="flex flex-col gap-2">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.CALLS_TITLE') }}
      </p>
      <div
        v-for="call in calls"
        :key="call.id"
        class="flex flex-col gap-1 rounded-lg bg-n-alpha-1 px-3 py-2 text-sm"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-n-slate-12">
            {{ call.from_number }} → {{ call.phone_number }}
          </span>
          <span class="text-xs text-n-slate-11">
            <template v-if="call.duration_seconds">
              {{ call.duration_seconds }}s ·
            </template>
            {{ call.status }}
          </span>
        </div>
        <!-- O que a chamada consumiu. Sem isto o custo por minuto só aparece
             na fatura. -->
        <div
          v-if="call.metrics && call.metrics.turns"
          class="flex flex-wrap gap-x-3 gap-y-0.5 font-mono text-xs text-n-slate-10"
        >
          <span>
            {{
              $t('INTEGRATION_SETTINGS.TWILIO.VOICE.TURNS', {
                count: call.metrics.turns,
              })
            }}
          </span>
          <span v-if="call.metrics.latency_median_ms">
            {{
              $t('INTEGRATION_SETTINGS.TWILIO.VOICE.LATENCY', {
                median: call.metrics.latency_median_ms,
                worst: call.metrics.latency_worst_ms,
              })
            }}
          </span>
          <span>
            {{
              $t('INTEGRATION_SETTINGS.TWILIO.VOICE.USAGE', {
                tokens: (
                  call.metrics.prompt_tokens + call.metrics.completion_tokens
                ).toLocaleString(),
                chars: (call.metrics.tts_characters || 0).toLocaleString(),
                seconds: call.metrics.stt_seconds,
              })
            }}
          </span>
        </div>
      </div>
    </div>

    <Dialog
      ref="credentialDialogRef"
      :title="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREDENTIAL_TITLE')"
      :description="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREDENTIAL_ONCE')"
      :show-cancel-button="false"
      :confirm-button-label="
        $t('INTEGRATION_SETTINGS.TWILIO.VOICE.CREDENTIAL_DONE')
      "
    >
      <div v-if="issuedCredential" class="flex flex-col gap-2 text-sm">
        <div class="rounded-lg bg-n-alpha-2 p-3 font-mono text-xs">
          <p>
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.SIP_USER') }}
            {{ issuedCredential.username }}
          </p>
          <p>
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.SIP_DOMAIN') }}
            {{ issuedCredential.domain }}
          </p>
          <p>
            {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.SIP_PASSWORD') }}
            {{ issuedCredential.password }}
          </p>
        </div>
        <Button
          sm
          slate
          faded
          icon="i-lucide-copy"
          :label="$t('INTEGRATION_SETTINGS.TWILIO.VOICE.COPY_CREDENTIAL')"
          @click="copyCredential"
        />
      </div>
    </Dialog>
  </div>
</template>
