<script setup>
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Nova campanha: nome, o número (inbox de WhatsApp por QR) e a primeira
// mensagem. O resto (variações, ritmo, lista) se ajusta na página da campanha,
// ainda em rascunho.
const QR_ADAPTER = '/chatwoot-adapter/';

const router = useRouter();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const inboxes = useMapGetter('inboxes/getInboxes');

const name = ref('');
const inboxId = ref('');
const text = ref('');
const isSaving = ref(false);

const qrInboxes = computed(() =>
  inboxes.value
    .filter(
      inbox =>
        inbox.channel_type === 'Channel::Api' &&
        (inbox.webhook_url || '').includes(QR_ADAPTER)
    )
    .map(inbox => ({ value: inbox.id, label: inbox.name }))
);
const canSave = computed(
  () => name.value.trim() && inboxId.value && text.value.trim()
);

const create = async () => {
  isSaving.value = true;
  try {
    const { data } = await OutreachAPI.create({
      name: name.value.trim(),
      inbox_id: inboxId.value,
      variants: [text.value.trim()],
    });
    router.push(accountScopedRoute('outreach_show', { campaignId: data.id }));
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('OUTREACH.API.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <h1 class="text-heading-2 text-n-slate-12">{{ $t('OUTREACH.NEW') }}</h1>
      <p class="text-body-main text-n-slate-11">
        {{ $t('OUTREACH.NEW_DESCRIPTION') }}
      </p>
    </header>
    <form class="flex flex-col max-w-xl gap-4 px-6 py-5" @submit.prevent>
      <Input v-model="name" :label="$t('OUTREACH.FIELDS.NAME')" />
      <label class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">
          {{ $t('OUTREACH.FIELDS.NUMBER') }}
        </span>
        <Select
          v-model="inboxId"
          :options="qrInboxes"
          :placeholder="$t('OUTREACH.FIELDS.NUMBER_PLACEHOLDER')"
        />
        <span v-if="!qrInboxes.length" class="text-xs text-n-slate-11">
          {{ $t('OUTREACH.FIELDS.NO_NUMBER') }}
        </span>
      </label>
      <label class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">
          {{ $t('OUTREACH.FIELDS.MESSAGE') }}
        </span>
        <TextArea v-model="text" :rows="5" />
      </label>
      <div class="flex gap-2">
        <Button
          :label="$t('OUTREACH.CREATE')"
          :is-loading="isSaving"
          :disabled="!canSave"
          @click="create"
        />
        <Button
          slate
          faded
          :label="$t('OUTREACH.CANCEL')"
          @click="router.push(accountScopedRoute('outreach_index'))"
        />
      </div>
    </form>
  </section>
</template>
