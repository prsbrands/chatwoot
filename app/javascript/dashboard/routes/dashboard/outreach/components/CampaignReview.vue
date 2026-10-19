<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

// Antes de iniciar: prepara a lista (quem pode receber e quem sai, com o
// motivo), manda um teste para um número da equipe e inicia.
const props = defineProps({
  campaign: { type: Object, required: true },
});
const emit = defineEmits(['updated']);

const { t } = useI18n();

const testPhone = ref('');
const isBusy = ref(false);

const metrics = computed(() => props.campaign.metrics);
const hasList = computed(() => props.campaign.audience.count > 0);
const isReady = computed(() => props.campaign.status === 'ready');

const run = async (action, doneKey, payload = {}) => {
  isBusy.value = true;
  try {
    const { data } = await OutreachAPI.action(
      props.campaign.id,
      action,
      payload
    );
    if (doneKey) useAlert(t(doneKey));
    emit('updated', data);
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('OUTREACH.API.ERROR')
    );
  } finally {
    isBusy.value = false;
  }
};

const prepare = () => run('prepare', 'OUTREACH.REVIEW.PREPARED');
const start = () => run('start', 'OUTREACH.REVIEW.STARTED');
const sendTest = () =>
  run('test', 'OUTREACH.REVIEW.TEST_SENT', { phone: testPhone.value });
</script>

<template>
  <section class="flex flex-col gap-4 p-4 rounded-xl bg-n-card">
    <h2 class="text-heading-3 text-n-slate-12">
      {{ $t('OUTREACH.REVIEW.TITLE') }}
    </h2>

    <div class="flex flex-col gap-2">
      <span class="text-sm text-n-slate-12">
        {{ $t('OUTREACH.REVIEW.TEST') }}
      </span>
      <div class="flex items-end gap-2">
        <Input
          v-model="testPhone"
          class="max-w-56"
          :placeholder="$t('OUTREACH.REVIEW.TEST_PHONE')"
        />
        <Button
          slate
          faded
          :label="$t('OUTREACH.REVIEW.SEND_TEST')"
          :is-loading="isBusy"
          :disabled="!testPhone.trim()"
          @click="sendTest"
        />
      </div>
      <p class="text-xs text-n-slate-11">
        {{ $t('OUTREACH.REVIEW.TEST_HINT') }}
      </p>
    </div>

    <div class="flex flex-col gap-2">
      <Button
        class="self-start"
        :label="$t('OUTREACH.REVIEW.PREPARE')"
        :is-loading="isBusy"
        :disabled="!hasList"
        @click="prepare"
      />
      <p v-if="!hasList" class="text-xs text-n-slate-11">
        {{ $t('OUTREACH.REVIEW.NO_LIST') }}
      </p>
    </div>

    <div v-if="isReady" class="flex flex-col gap-3">
      <p class="text-sm text-n-slate-12">
        {{ $t('OUTREACH.REVIEW.WILL_SEND', { count: metrics.pending }) }}
      </p>
      <ul
        v-if="metrics.excluded"
        class="flex flex-col gap-1 text-sm text-n-slate-11"
      >
        <li v-for="(count, reason) in metrics.excluded_by_reason" :key="reason">
          {{ count }} · {{ $t(`OUTREACH.REASON.${reason}`) }}
        </li>
      </ul>
      <Button
        class="self-start"
        :label="$t('OUTREACH.REVIEW.START')"
        :is-loading="isBusy"
        :disabled="!metrics.pending"
        @click="start"
      />
    </div>
  </section>
</template>
