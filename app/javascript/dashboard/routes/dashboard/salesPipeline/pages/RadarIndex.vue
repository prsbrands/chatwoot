<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import { dynamicTime } from 'shared/helpers/timeHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useDealFormat } from '../useDealFormat';

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { formatMoney, bandClass } = useDealFormat();
const currentUser = useMapGetter('getCurrentUser');

const BUCKETS = ['critical', 'at_risk', 'in_flight'];
const BUCKET_CLASSES = {
  critical: 'bg-n-ruby-3 text-n-ruby-11',
  at_risk: 'bg-n-amber-3 text-n-amber-11',
  in_flight: 'bg-n-blue-3 text-n-blue-11',
};

const rows = ref([]);
const noNextStep = ref([]);
const counts = ref({});
const isLoading = ref(true);
const takingOver = ref(null);

const fetchRadar = async () => {
  try {
    const { data } = await SalesPipelineAPI.radar();
    rows.value = data.payload;
    noNextStep.value = data.no_next_step;
    counts.value = data.counts;
  } finally {
    isLoading.value = false;
  }
};

const visibleBuckets = computed(() =>
  BUCKETS.filter(bucket => counts.value[bucket])
);

const ownerLine = row =>
  t(`SALES_PIPELINE.RADAR.OWNER.${row.owner.type}`, { name: row.owner.name });

// Hora prevista já passada: a varredura espera a janela das 8h às 20h ou o
// teto do número, e o envio sai na próxima rodada que couber.
const followupLine = row => {
  if (!row.followup_at) return t('SALES_PIPELINE.RADAR.NO_FOLLOWUP');
  if (row.followup_at * 1000 <= Date.now()) {
    return t('SALES_PIPELINE.RADAR.FOLLOWUP_SOON');
  }
  return t('SALES_PIPELINE.RADAR.FOLLOWUP_AT', {
    time: dynamicTime(row.followup_at),
  });
};

const open = row => {
  const { deal } = row;
  router.push(
    deal.conversation_id
      ? accountScopedRoute('inbox_conversation', {
          conversation_id: deal.conversation_id,
        })
      : accountScopedRoute('sales_pipeline_index')
  );
};

// Assumir: a conversa vai para quem clicou e sai de pendente. O Guard do bot
// para de responder quando o responsável é uma pessoa.
const takeOver = async row => {
  const conversationId = row.deal.conversation_id;
  takingOver.value = row.deal.id;
  try {
    await ConversationAPI.assignAgent({
      conversationId,
      agentId: currentUser.value.id,
    });
    await ConversationAPI.toggleStatus({ conversationId, status: 'open' });
    useAlert(t('SALES_PIPELINE.RADAR.TAKEN_OVER'));
    await fetchRadar();
  } catch (error) {
    useAlert(t('SALES_PIPELINE.RADAR.TAKE_OVER_ERROR'));
  } finally {
    takingOver.value = null;
  }
};

onMounted(fetchRadar);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col gap-1 min-w-0">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('SALES_PIPELINE.RADAR.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('SALES_PIPELINE.RADAR.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <span
          v-for="bucket in visibleBuckets"
          :key="bucket"
          class="px-2 py-0.5 text-xs font-medium rounded-md"
          :class="BUCKET_CLASSES[bucket]"
        >
          {{ counts[bucket] }}
          {{ $t(`SALES_PIPELINE.RADAR.BUCKET.${bucket}`) }}
        </span>
      </div>
    </header>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('SALES_PIPELINE.RADAR.LOADING') }}
    </div>

    <section
      v-if="!isLoading && noNextStep.length"
      class="flex flex-col gap-2 px-4 py-3 mx-6 mt-5 rounded-xl bg-n-amber-2 outline outline-1 outline-n-amber-5"
    >
      <h2 class="text-sm font-medium text-n-amber-11">
        {{
          $t(
            'SALES_PIPELINE.RADAR.NO_NEXT_STEP',
            { count: noNextStep.length },
            noNextStep.length
          )
        }}
      </h2>
      <p class="text-xs text-n-amber-11">
        {{ $t('SALES_PIPELINE.RADAR.NO_NEXT_STEP_HELP') }}
      </p>
      <ul class="flex flex-wrap gap-2 m-0 list-none">
        <li v-for="deal in noNextStep" :key="deal.id">
          <button
            type="button"
            class="px-2 py-1 text-xs rounded-md bg-n-card text-n-slate-12 hover:bg-n-alpha-2"
            @click="open({ deal })"
          >
            {{ deal.title }} · {{ deal.stage_name }}
          </button>
        </li>
      </ul>
    </section>

    <p v-if="!isLoading && !rows.length" class="px-6 py-5 text-sm text-n-slate-11">
      {{ $t('SALES_PIPELINE.RADAR.EMPTY') }}
    </p>

    <ul
      v-else-if="!isLoading"
      class="flex flex-col mx-6 my-5 list-none divide-y rounded-xl divide-n-weak bg-n-card outline outline-1 outline-n-container"
    >
      <li
        v-for="row in rows"
        :key="row.deal.id"
        class="flex flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3"
      >
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-md shrink-0"
          :class="BUCKET_CLASSES[row.bucket]"
        >
          {{ $t(`SALES_PIPELINE.RADAR.BUCKET.${row.bucket}`) }}
        </span>

        <button
          type="button"
          class="flex flex-col flex-1 min-w-48 text-start"
          @click="open(row)"
        >
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ row.deal.title }}
            <template v-if="row.deal.value_cents">
              · {{ formatMoney(row.deal.value_cents, row.deal.currency) }}
            </template>
          </span>
          <span class="text-xs text-n-slate-11">
            {{ row.deal.pipeline_name }} · {{ row.deal.stage_name }}
            <template v-if="row.last_activity_at">
              ·
              {{
                $t('SALES_PIPELINE.RADAR.IDLE', {
                  time: dynamicTime(row.last_activity_at),
                })
              }}
            </template>
          </span>
        </button>

        <span
          v-if="row.deal.insight?.score_band"
          class="px-2 py-0.5 text-xs font-medium rounded-md"
          :class="bandClass(row.deal)"
        >
          {{ row.deal.insight.score }}
        </span>

        <span class="flex flex-col text-xs basis-full sm:basis-56">
          <span class="text-n-slate-12">{{ ownerLine(row) }}</span>
          <span class="text-n-slate-11">{{ followupLine(row) }}</span>
        </span>

        <Button
          v-if="row.deal.conversation_id && row.owner.type !== 'user'"
          xs
          slate
          faded
          icon="i-lucide-hand"
          :label="$t('SALES_PIPELINE.RADAR.TAKE_OVER')"
          :is-loading="takingOver === row.deal.id"
          @click="takeOver(row)"
        />
      </li>
    </ul>
  </section>
</template>
