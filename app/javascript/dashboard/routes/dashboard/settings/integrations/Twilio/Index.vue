<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import TwilioAPI from 'dashboard/api/integrations/twilio';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();

const isLoading = ref(true);
const isSaving = ref(false);
const connection = ref({ connected: false });
const numbers = ref([]);
const smsWebhookUrl = ref('');
const form = ref({ account_sid: '', auth_token: '' });
const disconnectDialogRef = ref(null);

const canSubmit = computed(
  () => form.value.account_sid.trim() && form.value.auth_token.trim()
);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.TWILIO.API.ERROR')
  );

const fetchNumbers = async () => {
  try {
    const { data } = await TwilioAPI.numbers();
    numbers.value = data.numbers;
    smsWebhookUrl.value = data.sms_webhook_url;
  } catch (error) {
    alertError(error);
  }
};

const fetchAll = async () => {
  try {
    const { data } = await TwilioAPI.credentials();
    connection.value = data;
    if (data.connected) await fetchNumbers();
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const connect = async () => {
  if (!canSubmit.value) return;
  isSaving.value = true;
  try {
    const { data } = await TwilioAPI.connect(form.value);
    connection.value = data;
    form.value = { account_sid: '', auth_token: '' };
    useAlert(t('INTEGRATION_SETTINGS.TWILIO.API.CONNECTED'));
    await fetchNumbers();
  } catch (error) {
    alertError(error);
  } finally {
    isSaving.value = false;
  }
};

const confirmDisconnect = async () => {
  try {
    await TwilioAPI.disconnect();
    connection.value = { connected: false };
    numbers.value = [];
    useAlert(t('INTEGRATION_SETTINGS.TWILIO.API.DISCONNECTED'));
  } catch (error) {
    alertError(error);
  } finally {
    disconnectDialogRef.value.close();
  }
};

const copyWebhook = async () => {
  await copyTextToClipboard(smsWebhookUrl.value);
  useAlert(t('INTEGRATION_SETTINGS.TWILIO.WEBHOOK.COPIED'));
};

// O Twilio já sabe o que cada número pode fazer; mostrar isso evita o cliente
// descobrir que o número não envia SMS só quando a primeira mensagem falha.
const capabilityList = number =>
  Object.entries(number.capabilities)
    .filter(([, enabled]) => enabled)
    .map(([name]) => name.toUpperCase());

onMounted(fetchAll);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('INTEGRATION_SETTINGS.TWILIO.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.TWILIO.HEADER')"
        :description="$t('INTEGRATION_SETTINGS.TWILIO.DESCRIPTION')"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <!-- Conectar -->
      <div
        v-if="!connection.connected"
        class="flex flex-col gap-4 rounded-xl bg-n-card p-6 outline outline-1 outline-n-container"
      >
        <p class="text-sm text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.TWILIO.CONNECT.HELP') }}
        </p>
        <Input
          v-model="form.account_sid"
          :label="$t('INTEGRATION_SETTINGS.TWILIO.CONNECT.ACCOUNT_SID')"
          placeholder="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        />
        <Input
          v-model="form.auth_token"
          type="password"
          :label="$t('INTEGRATION_SETTINGS.TWILIO.CONNECT.AUTH_TOKEN')"
          :message="$t('INTEGRATION_SETTINGS.TWILIO.CONNECT.AUTH_TOKEN_HELP')"
        />
        <div class="flex justify-end">
          <Button
            blue
            :label="$t('INTEGRATION_SETTINGS.TWILIO.CONNECT.SUBMIT')"
            :disabled="!canSubmit"
            :is-loading="isSaving"
            @click="connect"
          />
        </div>
      </div>

      <!-- Conectado -->
      <div v-else class="flex flex-col gap-6">
        <div
          class="flex items-center justify-between gap-4 rounded-xl bg-n-card p-4 outline outline-1 outline-n-container"
        >
          <div class="min-w-0">
            <p class="font-medium text-n-slate-12">
              {{ connection.friendly_name }}
            </p>
            <p class="truncate text-xs text-n-slate-11">
              {{ connection.account_sid }}
            </p>
          </div>
          <Button
            sm
            ruby
            faded
            :label="$t('INTEGRATION_SETTINGS.TWILIO.DISCONNECT.BUTTON')"
            @click="disconnectDialogRef.open()"
          />
        </div>

        <!-- Webhook de SMS -->
        <div class="flex flex-col gap-2">
          <p class="text-sm font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.WEBHOOK.TITLE') }}
          </p>
          <p class="text-sm text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.WEBHOOK.HELP') }}
          </p>
          <div class="flex items-center gap-2">
            <code
              class="flex-1 truncate rounded-lg bg-n-alpha-2 px-3 py-2 font-mono text-xs text-n-slate-12"
            >
              {{ smsWebhookUrl }}
            </code>
            <Button
              sm
              slate
              faded
              icon="i-lucide-copy"
              :label="$t('INTEGRATION_SETTINGS.TWILIO.WEBHOOK.COPY')"
              @click="copyWebhook"
            />
          </div>
        </div>

        <!-- Números -->
        <div class="flex flex-col gap-2">
          <p class="text-sm font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.TITLE') }}
          </p>
          <p v-if="!numbers.length" class="text-sm text-n-slate-11">
            {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.EMPTY') }}
          </p>
          <table v-else class="min-w-full divide-y divide-n-weak">
            <thead>
              <tr class="text-left text-sm text-n-slate-11">
                <th class="py-2 pr-4 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.NUMBER') }}
                </th>
                <th class="py-2 pr-4 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.CAPABILITIES') }}
                </th>
                <th class="py-2 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.INBOX') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr v-for="number in numbers" :key="number.sid" class="text-sm">
                <td class="py-3 pr-4">
                  <p class="font-medium text-n-slate-12">
                    {{ number.phone_number }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{ number.friendly_name }}
                  </p>
                </td>
                <td class="py-3 pr-4">
                  <div class="flex flex-wrap gap-1">
                    <span
                      v-for="capability in capabilityList(number)"
                      :key="capability"
                      class="rounded-md bg-n-teal-3 px-2 py-0.5 text-xs font-medium text-n-teal-11"
                    >
                      {{ capability }}
                    </span>
                    <span
                      v-if="!capabilityList(number).length"
                      class="text-xs text-n-slate-10"
                    >
                      {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.NONE') }}
                    </span>
                  </div>
                </td>
                <td class="py-3">
                  <span v-if="number.inbox" class="text-n-slate-12">
                    {{ number.inbox.name }}
                  </span>
                  <span v-else class="text-n-slate-10">
                    {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.UNLINKED') }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <Dialog
        ref="disconnectDialogRef"
        type="alert"
        :title="$t('INTEGRATION_SETTINGS.TWILIO.DISCONNECT.TITLE')"
        :description="$t('INTEGRATION_SETTINGS.TWILIO.DISCONNECT.MESSAGE')"
        :confirm-button-label="
          $t('INTEGRATION_SETTINGS.TWILIO.DISCONNECT.CONFIRM')
        "
        @confirm="confirmDisconnect"
      />
    </template>
  </SettingsLayout>
</template>
