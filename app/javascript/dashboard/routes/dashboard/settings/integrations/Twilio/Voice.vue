<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import TwilioAPI from 'dashboard/api/integrations/twilio';
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
const selectedDomain = ref(null);
const isBusy = ref(false);
const newSubdomain = ref('');
const newUsername = ref('');
const issuedCredential = ref(null);
const credentialDialogRef = ref(null);

const routeForm = ref({
  phone_number: '',
  destination_type: 'sip',
  destination: '',
  ring_timeout: 20,
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

const canSaveRoute = computed(
  () =>
    routeForm.value.phone_number &&
    routeForm.value.destination.trim() &&
    routeForm.value.ring_timeout > 4
);

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

onMounted(fetchAll);
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
          <span class="font-mono">{{ route.destination }}</span>
          <span class="text-n-slate-10">
            ({{ route.destination_type.toUpperCase() }},
            {{ route.ring_timeout }}s)
          </span>
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

    <!-- Chamadas -->
    <div v-if="calls.length" class="flex flex-col gap-2">
      <p class="text-sm font-medium text-n-slate-12">
        {{ $t('INTEGRATION_SETTINGS.TWILIO.VOICE.CALLS_TITLE') }}
      </p>
      <div
        v-for="call in calls"
        :key="call.id"
        class="flex items-center justify-between rounded-lg bg-n-alpha-1 px-3 py-2 text-sm"
      >
        <span class="text-n-slate-12">
          {{ call.from_number }} → {{ call.phone_number }}
        </span>
        <span class="text-xs text-n-slate-11">{{ call.status }}</span>
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
