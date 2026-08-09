<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import TwilioAPI from 'dashboard/api/integrations/twilio';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const isLoading = ref(true);
const isSaving = ref(false);
const isLoadingMore = ref(false);
const connection = ref({ connected: false });
const numbers = ref([]);
const nextPageUrl = ref(null);
const search = ref('');
const smsWebhookUrl = ref('');
const form = ref({ account_sid: '', auth_token: '' });
const disconnectDialogRef = ref(null);
const provisionDialogRef = ref(null);
const provisionTarget = ref(null);
const inboxName = ref('');

const canSubmit = computed(
  () => form.value.account_sid.trim() && form.value.auth_token.trim()
);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.TWILIO.API.ERROR')
  );

const fetchNumbers = async ({ append = false } = {}) => {
  try {
    const { data } = await TwilioAPI.numbers({
      search: search.value,
      pageUrl: append ? nextPageUrl.value : null,
    });
    numbers.value = append ? [...numbers.value, ...data.numbers] : data.numbers;
    nextPageUrl.value = data.next_page_url;
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

// A busca roda no Twilio, não em memória — sem debounce seria uma chamada à API
// por tecla digitada.
const runSearch = useDebounceFn(() => fetchNumbers(), 400);
watch(search, () => {
  if (connection.value.connected) runSearch();
});

const loadMore = async () => {
  isLoadingMore.value = true;
  await fetchNumbers({ append: true });
  isLoadingMore.value = false;
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

const openProvisionDialog = number => {
  provisionTarget.value = number;
  inboxName.value = number.friendly_name || `SMS ${number.phone_number}`;
  provisionDialogRef.value.open();
};

const confirmProvision = async () => {
  isSaving.value = true;
  try {
    await TwilioAPI.provisionSms({
      phone_number: provisionTarget.value.phone_number,
      name: inboxName.value,
    });
    useAlert(t('INTEGRATION_SETTINGS.TWILIO.PROVISION.SUCCESS'));
    provisionDialogRef.value.close();
    store.dispatch('inboxes/get');
    await fetchNumbers();
  } catch (error) {
    alertError(error);
  } finally {
    isSaving.value = false;
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

// O 10DLC bloqueia o envio, não a capability — o Twilio segue reportando SMS
// num número americano não registrado. Só o console do Twilio sabe o status
// real, então aqui é aviso, não diagnóstico.
const needsA2pNotice = number =>
  number.capabilities.sms && number.phone_number.startsWith('+1');

const goToInbox = inbox =>
  router.push({ name: 'settings_inbox_show', params: { inboxId: inbox.id } });

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
        <div class="flex flex-col gap-3">
          <div class="flex items-center justify-between gap-4">
            <p class="text-sm font-medium text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.TITLE') }}
            </p>
            <Input
              v-model="search"
              class="w-64"
              :placeholder="$t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.SEARCH')"
            />
          </div>

          <p v-if="!numbers.length" class="text-sm text-n-slate-11">
            {{
              search
                ? $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.NO_MATCH')
                : $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.EMPTY')
            }}
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
                <th class="py-2 pr-4 font-medium">
                  {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.INBOX') }}
                </th>
                <th class="py-2 font-medium text-right">
                  {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.ACTIONS') }}
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
                  <p
                    v-if="needsA2pNotice(number)"
                    class="mt-1 flex items-center gap-1 text-xs text-n-amber-11"
                  >
                    <span class="i-lucide-info size-3 shrink-0" />
                    {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.A2P_NOTICE') }}
                  </p>
                </td>
                <td class="py-3 pr-4 align-top">
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
                <td class="py-3 pr-4 align-top">
                  <button
                    v-if="number.inbox"
                    class="text-n-brand hover:underline"
                    @click="goToInbox(number.inbox)"
                  >
                    {{ number.inbox.name }}
                  </button>
                  <span v-else class="text-n-slate-10">
                    {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.UNLINKED') }}
                  </span>
                </td>
                <td class="py-3 text-right align-top whitespace-nowrap">
                  <Button
                    v-if="!number.inbox"
                    sm
                    blue
                    ghost
                    :label="
                      $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.CONNECT_SMS')
                    "
                    :disabled="!number.capabilities.sms"
                    @click="openProvisionDialog(number)"
                  />
                  <span
                    v-if="!number.capabilities.sms"
                    class="block text-xs text-n-slate-10"
                  >
                    {{ $t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.NO_SMS') }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>

          <div v-if="nextPageUrl" class="flex justify-center pt-2">
            <Button
              sm
              slate
              faded
              :label="$t('INTEGRATION_SETTINGS.TWILIO.NUMBERS.LOAD_MORE')"
              :is-loading="isLoadingMore"
              @click="loadMore"
            />
          </div>
        </div>
      </div>

      <Dialog
        ref="provisionDialogRef"
        :title="$t('INTEGRATION_SETTINGS.TWILIO.PROVISION.TITLE')"
        :description="
          $t('INTEGRATION_SETTINGS.TWILIO.PROVISION.MESSAGE', {
            number: provisionTarget?.phone_number,
          })
        "
        :confirm-button-label="
          $t('INTEGRATION_SETTINGS.TWILIO.PROVISION.CONFIRM')
        "
        :is-loading="isSaving"
        @confirm="confirmProvision"
      >
        <Input
          v-model="inboxName"
          :label="$t('INTEGRATION_SETTINGS.TWILIO.PROVISION.INBOX_NAME')"
        />
      </Dialog>

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
