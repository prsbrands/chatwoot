<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { BOT_PROBLEMS } from 'dashboard/store/modules/connections';
import Button from 'dashboard/components-next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Icon from 'next/icon/Icon.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountId, accountScopedRoute } = useAccount();

const inboxes = useMapGetter('inboxes/getInboxes');
const inboxHealth = useMapGetter('connections/getInboxHealth');
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);
const hasBotLayer = computed(() =>
  isFeatureEnabledonAccount.value(accountId.value, FEATURE_FLAGS.BOT_PERSONAS)
);

const KINDS = {
  'Channel::Instagram': 'INSTAGRAM',
  'Channel::FacebookPage': 'MESSENGER',
  'Channel::WebWidget': 'WEBSITE',
  'Channel::Email': 'EMAIL',
  'Channel::Telegram': 'TELEGRAM',
  'Channel::Line': 'LINE',
  'Channel::Sms': 'SMS',
  'Channel::TwilioSms': 'TWILIO',
  'Channel::Tiktok': 'TIKTOK',
  'Channel::Api': 'API',
};

// O WhatsApp por QR é um canal API cujo webhook aponta para o adaptador do
// OpenWA — a mesma regra da tela WhatsApp Sessions.
const kindOf = inbox => {
  if (inbox.channel_type === 'Channel::Whatsapp') {
    return inbox.provider === '360dialog'
      ? 'WHATSAPP_360'
      : 'WHATSAPP_OFFICIAL';
  }
  if (String(inbox.webhook_url || '').includes('/chatwoot-adapter/')) {
    return 'WHATSAPP_QR';
  }
  return KINDS[inbox.channel_type] || 'OTHER';
};

// O QR é um canal API para o Chatwoot; na tela ele é WhatsApp, com o ícone do
// WhatsApp. A voz ganha o telefone (no template).
const iconInbox = row =>
  row.kind === 'WHATSAPP_QR'
    ? { ...row.inbox, channel_type: 'Channel::Whatsapp' }
    : row.inbox;

const rows = computed(() =>
  inboxes.value.map(inbox => {
    const health = inboxHealth.value(inbox.id);
    const botProblem = BOT_PROBLEMS.includes(health?.status);
    return {
      inbox,
      kind: kindOf(inbox),
      health,
      disconnected: Boolean(inbox.reauthorization_required),
      botProblem,
    };
  })
);

const needsAttention = row => row.disconnected || row.botProblem;
const byAttentionThenName = (a, b) =>
  Number(needsAttention(b)) - Number(needsAttention(a)) ||
  a.inbox.name.localeCompare(b.inbox.name);

const sections = computed(() => {
  const whatsapp = rows.value.filter(row => row.kind.startsWith('WHATSAPP'));
  const others = rows.value.filter(row => !row.kind.startsWith('WHATSAPP'));
  return [
    { id: 'WHATSAPP', rows: whatsapp.sort(byAttentionThenName) },
    { id: 'OTHERS', rows: others.sort(byAttentionThenName) },
  ].filter(section => section.rows.length);
});

const attentionCount = computed(() => rows.value.filter(needsAttention).length);

const botLine = row => {
  const { status, route } = row.health;
  if (status === 'ok') {
    return t('CONNECTIONS.BOT.OK', { persona: route.persona_name || '—' });
  }
  return t(`CONNECTIONS.BOT.${status.toUpperCase()}`);
};

const openInbox = row =>
  router.push(
    accountScopedRoute('settings_inbox_show', { inboxId: row.inbox.id })
  );

const fix = row => {
  if (row.botProblem) {
    router.push(
      accountScopedRoute(
        'settings_integrations_botlayer',
        {},
        { tab: 'channels' }
      )
    );
  } else if (row.kind === 'WHATSAPP_QR') {
    router.push(accountScopedRoute('settings_integrations_openwa'));
  } else {
    openInbox(row);
  }
};

const connectQr = () =>
  router.push(accountScopedRoute('settings_integrations_openwa'));
const connectOfficial = () =>
  router.push(
    accountScopedRoute('settings_inboxes_page_channel', {
      sub_page: 'whatsapp',
    })
  );

onMounted(() => {
  if (hasBotLayer.value) store.dispatch('connections/fetchHealth');
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col gap-1 min-w-0">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('CONNECTIONS.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('CONNECTIONS.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Button
          sm
          slate
          faded
          icon="i-lucide-qr-code"
          :label="$t('CONNECTIONS.CONNECT_QR')"
          @click="connectQr"
        />
        <Button
          sm
          icon="i-lucide-badge-check"
          :label="$t('CONNECTIONS.CONNECT_OFFICIAL')"
          @click="connectOfficial"
        />
      </div>
    </header>

    <div class="flex flex-col gap-6 px-6 py-5">
      <p
        v-if="attentionCount"
        class="px-3 py-2 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
      >
        {{ $t('CONNECTIONS.ATTENTION', { count: attentionCount }, attentionCount) }}
      </p>

      <p v-if="!rows.length" class="text-sm text-n-slate-11">
        {{ $t('CONNECTIONS.EMPTY') }}
      </p>

      <section
        v-for="section in sections"
        :key="section.id"
        class="flex flex-col gap-2"
      >
        <h2 class="text-xs font-medium tracking-wide uppercase text-n-slate-11">
          {{ $t(`CONNECTIONS.SECTION.${section.id}`) }}
        </h2>
        <ul
          class="flex flex-col m-0 list-none divide-y rounded-xl divide-n-weak bg-n-card outline outline-1 outline-n-container"
        >
          <li
            v-for="row in section.rows"
            :key="row.inbox.id"
            class="flex flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3"
          >
            <button
              type="button"
              class="flex items-center flex-1 min-w-48 gap-3 text-start"
              @click="openInbox(row)"
            >
              <Icon
                v-if="row.health?.status === 'voice'"
                icon="i-lucide-phone"
                class="size-5 shrink-0 text-n-slate-11"
              />
              <ChannelIcon
                v-else
                :inbox="iconInbox(row)"
                use-brand-icon
                class="size-5 shrink-0 text-n-slate-11"
              />
              <span class="flex flex-col min-w-0">
                <span class="text-sm font-medium truncate text-n-slate-12">
                  {{ row.inbox.name }}
                </span>
                <span class="text-xs text-n-slate-11">
                  {{ $t(`CONNECTIONS.KIND.${row.kind}`) }}
                  <template v-if="row.inbox.phone_number">
                    · {{ row.inbox.phone_number }}
                  </template>
                </span>
              </span>
            </button>

            <span
              class="px-2 py-0.5 text-xs font-medium rounded-md"
              :class="
                row.disconnected
                  ? 'bg-n-ruby-3 text-n-ruby-11'
                  : 'bg-n-teal-3 text-n-teal-11'
              "
            >
              {{
                row.disconnected
                  ? $t('CONNECTIONS.STATUS.DISCONNECTED')
                  : $t('CONNECTIONS.STATUS.CONNECTED')
              }}
            </span>

            <span
              v-if="row.health"
              class="text-xs basis-full sm:basis-64"
              :class="row.botProblem ? 'text-n-ruby-11' : 'text-n-slate-11'"
            >
              {{ botLine(row) }}
            </span>

            <Button
              v-if="needsAttention(row)"
              xs
              ruby
              faded
              :label="$t('CONNECTIONS.FIX')"
              @click="fix(row)"
            />
          </li>
        </ul>
      </section>
    </div>
  </section>
</template>
