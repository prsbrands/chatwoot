<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import AgendaAPI from 'dashboard/api/agenda';
import Button from 'dashboard/components-next/button/Button.vue';

// A agenda Google da pessoa logada: conectar, trocar de conta e desconectar.
// A volta do Google chega com ?google=connected|denied|missing_scope|failed.
const emit = defineEmits(['changed']);

const { t } = useI18n();
const route = useRoute();

const state = ref(null);
const isWorking = ref(false);

const connection = computed(() => state.value?.connection);
const needsReconnect = computed(
  () => connection.value?.status === 'reauthorization_required'
);

const load = async () => {
  const { data } = await AgendaAPI.googleConnection();
  state.value = data;
};

const connect = async () => {
  isWorking.value = true;
  try {
    const { data } = await AgendaAPI.connectGoogle();
    window.location.href = data.url;
  } catch (error) {
    useAlert(error.response?.data?.error || t('AGENDA.GOOGLE.ERROR'));
    isWorking.value = false;
  }
};

const disconnect = async () => {
  isWorking.value = true;
  try {
    const { data } = await AgendaAPI.disconnectGoogle();
    state.value = data;
    emit('changed');
  } finally {
    isWorking.value = false;
  }
};

onMounted(async () => {
  await load();
  const result = route.query.google;
  if (result) useAlert(t(`AGENDA.GOOGLE.RESULT.${result}`));
});
</script>

<template>
  <div
    v-if="state && (state.configured || connection)"
    class="flex flex-wrap items-center gap-3 px-4 py-3 rounded-xl bg-n-card outline outline-1"
    :class="needsReconnect ? 'outline-n-ruby-5' : 'outline-n-container'"
  >
    <span class="i-logos-google-calendar size-5 shrink-0" />
    <span class="flex flex-col flex-1 min-w-48">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('AGENDA.GOOGLE.TITLE') }}
      </span>
      <span
        class="text-xs"
        :class="needsReconnect ? 'text-n-ruby-11' : 'text-n-slate-11'"
      >
        <template v-if="needsReconnect">
          {{ $t('AGENDA.GOOGLE.RECONNECT', { email: connection.email }) }}
        </template>
        <template v-else-if="connection">
          {{ $t('AGENDA.GOOGLE.CONNECTED', { email: connection.email }) }}
        </template>
        <template v-else>{{ $t('AGENDA.GOOGLE.NOT_CONNECTED') }}</template>
      </span>
    </span>
    <Button
      v-if="!connection || needsReconnect"
      sm
      :label="
        needsReconnect
          ? $t('AGENDA.GOOGLE.RECONNECT_BUTTON')
          : $t('AGENDA.GOOGLE.CONNECT')
      "
      :is-loading="isWorking"
      @click="connect"
    />
    <template v-else>
      <Button
        sm
        slate
        faded
        :label="$t('AGENDA.GOOGLE.SWITCH')"
        :disabled="isWorking"
        @click="connect"
      />
      <Button
        sm
        ruby
        faded
        :label="$t('AGENDA.GOOGLE.DISCONNECT')"
        :is-loading="isWorking"
        @click="disconnect"
      />
    </template>
  </div>
</template>
