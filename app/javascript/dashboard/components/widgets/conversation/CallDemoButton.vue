<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  loadBotRoutes,
  loadVoicePersonas,
} from 'dashboard/helper/voiceBotCall';
import TwilioAPI from 'dashboard/api/integrations/twilio';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  contact: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const { isAdmin } = useAdmin();

const botRoutes = ref([]);
const voicePersonas = ref([]);
const dialogRef = ref(null);
const isCalling = ref(false);
const form = ref({ phone_number: '', to: '', persona_slug: '' });

const isAvailable = computed(
  () => Boolean(props.contact?.phone_number) && botRoutes.value.length > 0
);

const fromOptions = computed(() =>
  botRoutes.value.map(route => ({
    value: route.phone_number,
    label: route.phone_number,
  }))
);

// Em branco = usa a persona da rota, que é a de quem atende.
const personaOptions = computed(() => [
  { value: '', label: t('CONVERSATION.HEADER.CALL_DEMO.PERSONA_ROUTE') },
  ...voicePersonas.value.map(persona => ({
    value: persona.slug,
    label: persona.display_name,
  })),
]);

const canCall = computed(
  () =>
    Boolean(form.value.phone_number) && /^\+\d{8,}$/.test(form.value.to.trim())
);

// O telefone do contato entra preenchido, mas editável: muito contato foi
// gravado sem código de país, e o Twilio recusa o que não for E.164.
const openDialog = async () => {
  form.value = {
    phone_number: botRoutes.value[0].phone_number,
    to: props.contact.phone_number,
    persona_slug: '',
  };
  dialogRef.value.open();
  voicePersonas.value = await loadVoicePersonas();
};

const placeCall = async () => {
  if (!canCall.value) return;
  isCalling.value = true;
  try {
    const { data } = await TwilioAPI.placeVoiceCall({
      ...form.value,
      to: form.value.to.trim(),
    });
    useAlert(
      t('CONVERSATION.HEADER.CALL_DEMO.PLACED', { status: data.status })
    );
    dialogRef.value.close();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('CONVERSATION.HEADER.CALL_DEMO.FAILED')
    );
  } finally {
    isCalling.value = false;
  }
};

// O disparo é admin-only, como o resto da integração: uma ligação custa
// dinheiro e toca no telefone de alguém.
onMounted(async () => {
  if (!isAdmin.value) return;
  botRoutes.value = await loadBotRoutes();
});
</script>

<template>
  <template v-if="isAvailable">
    <NextButton
      v-tooltip.bottom="$t('CONVERSATION.HEADER.CALL_DEMO.TOOLTIP')"
      sm
      ghost
      slate
      icon="i-lucide-phone-outgoing"
      @click="openDialog"
    />
    <Dialog
      ref="dialogRef"
      :title="$t('CONVERSATION.HEADER.CALL_DEMO.TITLE')"
      :description="$t('CONVERSATION.HEADER.CALL_DEMO.DESCRIPTION')"
      :confirm-button-label="$t('CONVERSATION.HEADER.CALL_DEMO.ACTION')"
      :disable-confirm-button="!canCall"
      :is-loading="isCalling"
      @confirm="placeCall"
    >
      <div class="flex flex-col gap-4">
        <!-- O `Select` não tem prop de rótulo — só usa `label` dentro das
             opções. Rotular por fora é o padrão da aba Voz das integrações. -->
        <div class="flex flex-col gap-1">
          <label class="text-sm text-n-slate-12">
            {{ $t('CONVERSATION.HEADER.CALL_DEMO.FROM') }}
          </label>
          <Select v-model="form.phone_number" :options="fromOptions" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm text-n-slate-12">
            {{ $t('CONVERSATION.HEADER.CALL_DEMO.TO') }}
          </label>
          <Input v-model="form.to" placeholder="+50761234567" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm text-n-slate-12">
            {{ $t('CONVERSATION.HEADER.CALL_DEMO.PERSONA') }}
          </label>
          <Select v-model="form.persona_slug" :options="personaOptions" />
        </div>
        <p class="text-xs text-n-slate-11">
          {{ $t('CONVERSATION.HEADER.CALL_DEMO.CONSENT') }}
        </p>
      </div>
    </Dialog>
  </template>
</template>
