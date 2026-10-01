<script setup>
import { useRouter } from 'vue-router';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';

// A sessão do WhatsApp por QR caiu (Openwa::SessionWatchJob). Reconectar é
// ler o QR de novo na mesma sessão, na tela do OpenWA: excluir e criar outra
// conexão deixa esta inbox morta e o número duplicado.
const router = useRouter();

const openWhatsappSessions = () => {
  router.push({ name: 'settings_integrations_openwa' });
};
</script>

<template>
  <InboxReconnectionRequired
    :description="$t('INBOX_MGMT.OPENWA_DISCONNECTED')"
    :action-label="$t('INBOX_MGMT.OPENWA_RECONNECT')"
    @reauthorize="openWhatsappSessions"
  />
</template>
