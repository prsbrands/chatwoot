<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useStore } from 'dashboard/composables/store';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CampaignAudience from '../components/CampaignAudience.vue';
import CampaignForm from '../components/CampaignForm.vue';
import CampaignResults from '../components/CampaignResults.vue';
import CampaignReview from '../components/CampaignReview.vue';
import { STATUS_CLASSES } from '../constants';

// A campanha: em rascunho ou pronta, a mensagem, o ritmo, a lista e a revisão;
// depois de iniciada, o andamento. Pausar, retomar e cancelar ficam no topo.
const POLL_INTERVAL = 10000;

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const store = useStore();
const { accountScopedRoute } = useAccount();

const campaign = ref(null);
let timer = null;

const editable = computed(() =>
  ['draft', 'ready'].includes(campaign.value?.status)
);
const started = computed(() =>
  ['running', 'paused', 'completed', 'cancelled'].includes(
    campaign.value?.status
  )
);
const systemPaused = computed(
  () =>
    campaign.value?.status === 'paused' &&
    campaign.value.paused_reason !== 'manual'
);

const fetchCampaign = async () => {
  const { data } = await OutreachAPI.show(route.params.campaignId);
  campaign.value = data;
};

const refreshed = data => {
  campaign.value = data;
  store.dispatch('outreach/fetchAttentionCount');
};

const act = async (action, doneKey) => {
  try {
    const { data } = await OutreachAPI.action(campaign.value.id, action);
    useAlert(t(doneKey));
    refreshed(data);
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('OUTREACH.API.ERROR')
    );
  }
};

const remove = async () => {
  await OutreachAPI.delete(campaign.value.id);
  router.push(accountScopedRoute('outreach_index'));
};

onMounted(async () => {
  await fetchCampaign();
  timer = setInterval(() => {
    if (started.value) fetchCampaign();
  }, POLL_INTERVAL);
});
onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div v-if="!campaign" class="flex px-6 py-5"><Spinner /></div>
    <template v-else>
      <header
        class="flex flex-wrap items-center justify-between gap-3 px-6 py-5 border-b border-n-weak"
      >
        <div class="flex flex-col gap-1">
          <h1 class="flex items-center gap-2 text-heading-2 text-n-slate-12">
            {{ campaign.name }}
            <span
              class="px-2 py-0.5 text-xs rounded-md"
              :class="STATUS_CLASSES[campaign.status]"
            >
              {{ $t(`OUTREACH.STATUS.${campaign.status}`) }}
            </span>
          </h1>
          <p class="text-body-main text-n-slate-11">
            {{ campaign.inbox_name }}
          </p>
        </div>
        <div class="flex items-center gap-2">
          <Button
            slate
            faded
            sm
            :label="$t('OUTREACH.BACK')"
            @click="router.push(accountScopedRoute('outreach_index'))"
          />
          <Button
            v-if="campaign.status === 'running'"
            sm
            amber
            icon="i-lucide-pause"
            :label="$t('OUTREACH.ACTIONS.PAUSE')"
            @click="act('pause', 'OUTREACH.DONE.PAUSE')"
          />
          <Button
            v-if="campaign.status === 'paused'"
            sm
            icon="i-lucide-play"
            :label="$t('OUTREACH.ACTIONS.RESUME')"
            @click="act('start', 'OUTREACH.DONE.RESUME')"
          />
          <Button
            v-if="['ready', 'running', 'paused'].includes(campaign.status)"
            sm
            ruby
            faded
            :label="$t('OUTREACH.ACTIONS.CANCEL')"
            @click="act('cancel', 'OUTREACH.DONE.CANCEL')"
          />
          <Button
            v-if="['draft', 'cancelled'].includes(campaign.status)"
            sm
            ruby
            faded
            icon="i-lucide-trash-2"
            :label="$t('OUTREACH.ACTIONS.DELETE')"
            @click="remove"
          />
        </div>
      </header>

      <div class="flex flex-col max-w-4xl gap-4 px-6 py-5">
        <p
          v-if="systemPaused"
          class="p-3 text-sm rounded-lg bg-n-ruby-3 text-n-ruby-11"
        >
          {{ $t(`OUTREACH.PAUSED_REASON.${campaign.paused_reason}`) }}
          {{ $t('OUTREACH.PAUSED_HINT') }}
        </p>
        <template v-if="editable">
          <CampaignForm :campaign="campaign" @updated="refreshed" />
          <CampaignAudience :campaign="campaign" @updated="refreshed" />
          <CampaignReview :campaign="campaign" @updated="refreshed" />
        </template>
        <CampaignResults v-if="started" :campaign="campaign" />
      </div>
    </template>
  </section>
</template>
