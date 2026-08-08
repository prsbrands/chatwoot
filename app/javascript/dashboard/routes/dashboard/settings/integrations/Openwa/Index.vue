<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import OpenwaAPI from 'dashboard/api/integrations/openwa';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import SettingsLayout from '../../SettingsLayout.vue';
import BaseSettingsHeader from '../../components/BaseSettingsHeader.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const sessions = ref([]);
const adapterInstances = ref([]);
const isLoading = ref(false);

const createDialogRef = ref(null);
const newSessionName = ref('');
const withBot = ref(true);
const selectedBotId = ref(null);
const isCreating = ref(false);

const qrDialogRef = ref(null);
const qrSession = ref(null);
const qrImage = ref('');
const qrStatus = ref('');
let qrTimer = null;

const deleteDialogRef = ref(null);
const sessionToDelete = ref(null);

const NEW_INBOX = 0;
const selectedInboxId = ref(NEW_INBOX);

const agentBots = computed(() => getters['agentBots/getBots'].value);
const botOptions = computed(() =>
  agentBots.value.map(bot => ({ value: bot.id, label: bot.name }))
);

// Inboxes de API ainda não ligadas a uma sessão podem ser reaproveitadas;
// o padrão continua sendo criar uma inbox nova dedicada à sessão.
const inboxOptions = computed(() => {
  const usedInboxIds = adapterInstances.value.map(
    instance => instance.inbox_id
  );
  const apiInboxes = getters['inboxes/getInboxes'].value
    .filter(
      inbox =>
        inbox.channel_type === 'Channel::Api' &&
        !usedInboxIds.includes(inbox.id)
    )
    .map(inbox => ({ value: inbox.id, label: inbox.name }));
  return [
    {
      value: NEW_INBOX,
      label: t('INTEGRATION_SETTINGS.OPENWA.ADD.INBOX_NEW'),
    },
    ...apiInboxes,
  ];
});

const STATUS_STYLES = {
  ready: 'bg-n-teal-3 text-n-teal-11',
  qr_ready: 'bg-n-blue-3 text-n-blue-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
  action_required: 'bg-n-ruby-3 text-n-ruby-11',
};

const statusClass = status =>
  STATUS_STYLES[status] || 'bg-n-slate-3 text-n-slate-11';

const statusLabel = status =>
  t(`INTEGRATION_SETTINGS.OPENWA.STATUS.${status.toUpperCase()}`);

const instanceFor = session =>
  adapterInstances.value.find(instance => instance.session_id === session.id);

const inboxIdFor = session => instanceFor(session)?.inbox_id;

const inboxLabelFor = session => {
  const instance = instanceFor(session);
  if (!instance?.inbox_id) return '';
  return instance.inbox_name || `#${instance.inbox_id}`;
};

const fetchSessions = async () => {
  isLoading.value = true;
  try {
    const { data } = await OpenwaAPI.get();
    sessions.value = data.sessions;
    adapterInstances.value = data.adapter_instances;
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INTEGRATION_SETTINGS.OPENWA.API.ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const stopQrPolling = () => {
  clearTimeout(qrTimer);
  qrTimer = null;
};

const pollQr = async () => {
  if (!qrSession.value) return;
  try {
    const { data } = await OpenwaAPI.qr(qrSession.value.id);
    qrStatus.value = data.status;
    qrImage.value = data.qrCode || '';
    if (data.status === 'ready') {
      stopQrPolling();
      fetchSessions();
      return;
    }
  } catch {
    // O QR pode não estar disponível enquanto a sessão inicializa; seguimos consultando.
  }
  qrTimer = setTimeout(pollQr, 3000);
};

const openQrDialog = session => {
  qrSession.value = session;
  qrStatus.value = session.status;
  qrImage.value = '';
  qrDialogRef.value.open();
  pollQr();
};

const closeQrDialog = () => {
  stopQrPolling();
  qrSession.value = null;
};

const openCreateDialog = () => {
  newSessionName.value = '';
  withBot.value = agentBots.value.length > 0;
  selectedInboxId.value = NEW_INBOX;
  createDialogRef.value.open();
};

const createSession = async () => {
  isCreating.value = true;
  try {
    const { data } = await OpenwaAPI.create({
      name: newSessionName.value,
      agent_bot_id: withBot.value ? selectedBotId.value : null,
      inbox_id: selectedInboxId.value || null,
    });
    createDialogRef.value.close();
    useAlert(t('INTEGRATION_SETTINGS.OPENWA.API.CREATE_SUCCESS'));
    if (data.bot_route && !['created', 'skipped'].includes(data.bot_route)) {
      useAlert(
        t(`INTEGRATION_SETTINGS.OPENWA.BOT_ROUTE.${data.bot_route.toUpperCase()}`)
      );
    }
    await fetchSessions();
    const created = sessions.value.find(
      session => session.id === data.session.id
    );
    openQrDialog(created || data.session);
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INTEGRATION_SETTINGS.OPENWA.API.ERROR')
    );
  } finally {
    isCreating.value = false;
  }
};

const runAction = async (action, session) => {
  try {
    await OpenwaAPI[action](session.id);
    useAlert(t('INTEGRATION_SETTINGS.OPENWA.API.ACTION_SUCCESS'));
    fetchSessions();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INTEGRATION_SETTINGS.OPENWA.API.ERROR')
    );
  }
};

const openDeleteDialog = session => {
  sessionToDelete.value = session;
  deleteDialogRef.value.open();
};

const deleteSession = async () => {
  try {
    await OpenwaAPI.delete(sessionToDelete.value.id);
    useAlert(t('INTEGRATION_SETTINGS.OPENWA.DELETE.SUCCESS'));
    fetchSessions();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('INTEGRATION_SETTINGS.OPENWA.API.ERROR')
    );
  } finally {
    deleteDialogRef.value.close();
  }
};

watch(agentBots, bots => {
  if (selectedBotId.value === null && bots.length) {
    selectedBotId.value = bots[0].id;
  }
});

onMounted(() => {
  fetchSessions();
  store.dispatch('agentBots/get');
  store.dispatch('inboxes/get');
});

onBeforeUnmount(stopQrPolling);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading && !sessions.length"
    :loading-message="$t('INTEGRATION_SETTINGS.OPENWA.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.OPENWA.HEADER')"
        :description="$t('INTEGRATION_SETTINGS.OPENWA.DESCRIPTION')"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      >
        <template #actions>
          <Button
            blue
            :label="$t('INTEGRATION_SETTINGS.OPENWA.ADD.BUTTON')"
            icon="i-lucide-circle-plus"
            @click="openCreateDialog"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <p
        v-if="!sessions.length"
        class="flex items-center justify-center py-16 text-body-main text-n-slate-11"
      >
        {{ $t('INTEGRATION_SETTINGS.OPENWA.EMPTY') }}
      </p>
      <table v-else class="min-w-full divide-y divide-n-weak">
        <thead>
          <tr class="text-left text-sm text-n-slate-11">
            <th class="py-3 pr-4 font-medium">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.LIST.NAME') }}
            </th>
            <th class="py-3 pr-4 font-medium">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.LIST.STATUS') }}
            </th>
            <th class="py-3 pr-4 font-medium">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.LIST.PHONE') }}
            </th>
            <th class="py-3 pr-4 font-medium">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.LIST.INBOX') }}
            </th>
            <th class="py-3 font-medium text-right">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.LIST.ACTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr v-for="session in sessions" :key="session.id" class="text-sm">
            <td class="py-3 pr-4 font-medium text-n-slate-12">
              {{ session.name }}
            </td>
            <td class="py-3 pr-4">
              <span
                class="inline-flex rounded-md px-2 py-0.5 text-xs font-medium"
                :class="statusClass(session.status)"
              >
                {{ statusLabel(session.status) }}
              </span>
            </td>
            <td class="py-3 pr-4 text-n-slate-11">
              {{ session.phone || '—' }}
            </td>
            <td class="py-3 pr-4 text-n-slate-11">
              <router-link
                v-if="inboxIdFor(session)"
                class="text-n-blue-text hover:underline"
                :to="{
                  name: 'settings_inbox_show',
                  params: { inboxId: inboxIdFor(session) },
                }"
              >
                {{ inboxLabelFor(session) }}
              </router-link>
              <span v-else>—</span>
            </td>
            <td class="py-3 text-right whitespace-nowrap">
              <Button
                v-if="session.status !== 'ready'"
                sm
                slate
                ghost
                :label="$t('INTEGRATION_SETTINGS.OPENWA.ACTIONS.PAIR')"
                @click="openQrDialog(session)"
              />
              <Button
                v-if="session.status === 'disconnected'"
                sm
                slate
                ghost
                :label="$t('INTEGRATION_SETTINGS.OPENWA.ACTIONS.START')"
                @click="runAction('start', session)"
              />
              <Button
                v-if="session.status === 'ready'"
                sm
                slate
                ghost
                :label="$t('INTEGRATION_SETTINGS.OPENWA.ACTIONS.STOP')"
                @click="runAction('stop', session)"
              />
              <Button
                v-if="session.status === 'ready'"
                sm
                slate
                ghost
                :label="$t('INTEGRATION_SETTINGS.OPENWA.ACTIONS.LOGOUT')"
                @click="runAction('logout', session)"
              />
              <Button
                sm
                ruby
                ghost
                icon="i-lucide-trash-2"
                @click="openDeleteDialog(session)"
              />
            </td>
          </tr>
        </tbody>
      </table>

      <Dialog
        ref="createDialogRef"
        :title="$t('INTEGRATION_SETTINGS.OPENWA.ADD.TITLE')"
        :description="$t('INTEGRATION_SETTINGS.OPENWA.ADD.DESC')"
        :confirm-button-label="$t('INTEGRATION_SETTINGS.OPENWA.ADD.CREATE')"
        :is-loading="isCreating"
        :disable-confirm-button="isCreating || !newSessionName"
        @confirm="createSession"
      >
        <div class="flex flex-col gap-4">
          <Input
            v-model="newSessionName"
            :label="$t('INTEGRATION_SETTINGS.OPENWA.ADD.NAME_LABEL')"
            :placeholder="$t('INTEGRATION_SETTINGS.OPENWA.ADD.NAME_PLACEHOLDER')"
            :message="$t('INTEGRATION_SETTINGS.OPENWA.ADD.NAME_HELP')"
          />
          <div class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.ADD.INBOX_LABEL') }}
            </span>
            <Select v-model="selectedInboxId" :options="inboxOptions" />
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.ADD.INBOX_HELP') }}
            </span>
          </div>
          <div
            v-if="botOptions.length"
            class="flex items-center justify-between gap-2"
          >
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.ADD.WITH_BOT') }}
            </span>
            <Switch v-model="withBot" />
          </div>
          <div v-if="withBot && botOptions.length" class="flex flex-col gap-1">
            <span class="text-sm text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.ADD.BOT_LABEL') }}
            </span>
            <Select v-model="selectedBotId" :options="botOptions" />
          </div>
        </div>
      </Dialog>

      <Dialog
        ref="qrDialogRef"
        :title="$t('INTEGRATION_SETTINGS.OPENWA.QR.TITLE')"
        :show-confirm-button="false"
        :cancel-button-label="$t('INTEGRATION_SETTINGS.OPENWA.QR.CLOSE')"
        @close="closeQrDialog"
      >
        <div class="flex flex-col items-center gap-4 py-2">
          <template v-if="qrStatus === 'ready'">
            <span class="i-lucide-circle-check-big size-12 text-n-teal-10" />
            <p class="text-center text-n-slate-12">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.QR.CONNECTED') }}
            </p>
          </template>
          <template v-else-if="qrImage">
            <img
              :src="qrImage"
              class="size-56 rounded-lg border border-n-weak bg-white p-2"
              alt="QR"
            />
            <p class="text-center text-sm text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.QR.INSTRUCTIONS') }}
            </p>
          </template>
          <template v-else>
            <Spinner />
            <p class="text-center text-sm text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.OPENWA.QR.WAITING') }}
            </p>
          </template>
        </div>
      </Dialog>

      <Dialog
        ref="deleteDialogRef"
        type="alert"
        :title="$t('INTEGRATION_SETTINGS.OPENWA.DELETE.TITLE')"
        :description="
          $t('INTEGRATION_SETTINGS.OPENWA.DELETE.MESSAGE', {
            name: sessionToDelete?.name,
          })
        "
        :confirm-button-label="$t('INTEGRATION_SETTINGS.OPENWA.DELETE.CONFIRM')"
        @confirm="deleteSession"
      />
    </template>
  </SettingsLayout>
</template>
