<script setup>
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useLocale } from 'shared/composables/useLocale';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { STATUS_CLASSES } from '../constants';

// Campanhas por QR: a lista, com o andamento de cada uma.
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { resolvedLocale } = useLocale();

const campaigns = ref([]);
const isLoading = ref(true);

const dateLabel = stamp =>
  stamp
    ? new Intl.DateTimeFormat(resolvedLocale.value, {
        dateStyle: 'medium',
      }).format(new Date(stamp * 1000))
    : '—';

onMounted(async () => {
  try {
    const { data } = await OutreachAPI.list();
    campaigns.value = data.payload;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col gap-1">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('OUTREACH.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('OUTREACH.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Button
          slate
          faded
          sm
          :label="$t('OUTREACH.EXCLUSIONS.LINK')"
          @click="router.push(accountScopedRoute('outreach_suppressions'))"
        />
        <Button
          sm
          icon="i-lucide-plus"
          :label="$t('OUTREACH.NEW')"
          @click="router.push(accountScopedRoute('outreach_new'))"
        />
      </div>
    </header>

    <div v-if="isLoading" class="flex px-6 py-5"><Spinner /></div>
    <p v-else-if="!campaigns.length" class="px-6 py-5 text-sm text-n-slate-11">
      {{ $t('OUTREACH.EMPTY') }}
    </p>
    <ul v-else class="flex flex-col max-w-4xl gap-3 px-6 py-5">
      <li
        v-for="campaign in campaigns"
        :key="campaign.id"
        class="flex flex-wrap items-center gap-3 p-4 cursor-pointer rounded-xl bg-n-card outline outline-1 outline-n-container hover:bg-n-alpha-1"
        @click="
          router.push(
            accountScopedRoute('outreach_show', { campaignId: campaign.id })
          )
        "
      >
        <div class="flex flex-col flex-1 min-w-48 gap-0.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ campaign.name }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ campaign.inbox_name }} · {{ dateLabel(campaign.created_at) }}
          </span>
        </div>
        <span
          class="px-2 py-0.5 text-xs rounded-md"
          :class="STATUS_CLASSES[campaign.status]"
        >
          {{ $t(`OUTREACH.STATUS.${campaign.status}`) }}
        </span>
        <span
          v-if="campaign.paused_reason && campaign.paused_reason !== 'manual'"
          class="px-2 py-0.5 text-xs rounded-md bg-n-ruby-3 text-n-ruby-11"
        >
          {{ $t(`OUTREACH.PAUSED_REASON.${campaign.paused_reason}`) }}
        </span>
        <dl class="flex gap-4 text-xs text-n-slate-11">
          <div class="flex flex-col">
            <dt>{{ $t('OUTREACH.METRICS.SENT') }}</dt>
            <dd class="text-sm text-n-slate-12">{{ campaign.metrics.sent }}</dd>
          </div>
          <div class="flex flex-col">
            <dt>{{ $t('OUTREACH.METRICS.REPLIED') }}</dt>
            <dd class="text-sm text-n-slate-12">
              {{ campaign.metrics.replied }}
            </dd>
          </div>
          <div class="flex flex-col">
            <dt>{{ $t('OUTREACH.METRICS.PENDING') }}</dt>
            <dd class="text-sm text-n-slate-12">
              {{ campaign.metrics.pending }}
            </dd>
          </div>
        </dl>
      </li>
    </ul>
  </section>
</template>
