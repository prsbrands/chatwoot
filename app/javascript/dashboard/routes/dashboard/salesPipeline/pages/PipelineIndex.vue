<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import LostReasonDialog from '../components/LostReasonDialog.vue';
import StagesDialog from '../components/StagesDialog.vue';
import { useDealFormat } from '../useDealFormat';

// Kanban do funil (bloco 3a). Arrastar um negocio para outra coluna troca a
// etapa no servidor, que grava a transicao com quem moveu. Ir para a etapa de
// perda pede o motivo antes; cancelar devolve o card a coluna de origem.
const { t } = useI18n();
const { isAdmin } = useAdmin();
const { formatMoney, sinceStageChange } = useDealFormat();

const pipeline = ref(null);
const columns = ref({});
const isLoading = ref(true);
const lostDialogRef = ref(null);
const stagesDialogRef = ref(null);
let pendingLost = null;

const stages = computed(() => pipeline.value?.stages || []);

const alertError = error =>
  useAlert(error.response?.data?.error || t('SALES_PIPELINE.API.ERROR'));

const load = async () => {
  try {
    const { data } = await SalesPipelineAPI.pipelines();
    pipeline.value =
      data.payload.find(item => item.is_default) || data.payload[0];
    const { data: deals } = await SalesPipelineAPI.deals({
      pipeline_id: pipeline.value.id,
    });
    columns.value = Object.fromEntries(
      pipeline.value.stages.map(stage => [
        stage.id,
        deals.payload.filter(deal => deal.stage_id === stage.id),
      ])
    );
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const columnTotal = stageId =>
  (columns.value[stageId] || []).reduce(
    (total, deal) => total + (deal.value_cents || 0),
    0
  );

const moveDeal = async (deal, stage, lostReason) => {
  try {
    const { data } = await SalesPipelineAPI.updateDeal(deal.id, {
      stage_id: stage.id,
      lost_reason: lostReason,
    });
    Object.assign(deal, data);
    useAlert(t('SALES_PIPELINE.API.MOVED', { stage: stage.name }));
  } catch (error) {
    alertError(error);
    await load();
  }
};

const onDrop = (stage, event) => {
  if (!event.added) return;
  const deal = event.added.element;
  if (stage.kind === 'lost') {
    pendingLost = { deal, stage };
    lostDialogRef.value.open(stage.name);
    return;
  }
  moveDeal(deal, stage);
};

const confirmLost = reason => {
  const { deal, stage } = pendingLost;
  pendingLost = null;
  moveDeal(deal, stage, reason);
};

// Cancelou o motivo: o card volta para onde estava.
const cancelLost = () => {
  pendingLost = null;
  load();
};

onMounted(load);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="flex items-center justify-between gap-4 px-6 py-4 border-b border-n-weak"
    >
      <h1 class="text-heading-2 text-n-slate-12">
        {{ pipeline?.name || $t('SALES_PIPELINE.HEADER') }}
      </h1>
      <Button
        v-if="isAdmin && pipeline"
        sm
        faded
        slate
        icon="i-lucide-settings-2"
        :label="$t('SALES_PIPELINE.MANAGE_STAGES')"
        @click="stagesDialogRef.open()"
      />
    </header>

    <div
      v-if="isLoading"
      class="flex items-center justify-center flex-1 gap-2 text-body-main text-n-slate-11"
    >
      <Spinner />
      {{ $t('SALES_PIPELINE.LOADING') }}
    </div>

    <div v-else class="flex flex-1 gap-3 p-4 overflow-x-auto">
      <div
        v-for="stage in stages"
        :key="stage.id"
        class="flex flex-col w-72 shrink-0 rounded-xl bg-n-alpha-1"
      >
        <div class="flex flex-col gap-0.5 px-3 pt-3 pb-2">
          <div class="flex items-center justify-between gap-2">
            <span class="truncate text-heading-3 text-n-slate-12">
              {{ stage.name }}
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ (columns[stage.id] || []).length }}
            </span>
          </div>
          <span
            v-if="columnTotal(stage.id)"
            class="text-label-small text-n-slate-11"
          >
            {{
              formatMoney(
                columnTotal(stage.id),
                columns[stage.id][0]?.currency
              )
            }}
          </span>
        </div>
        <Draggable
          v-model="columns[stage.id]"
          group="deals"
          item-key="id"
          class="flex flex-col flex-1 gap-2 px-2 pb-2 overflow-y-auto min-h-24"
          @change="event => onDrop(stage, event)"
        >
          <template #item="{ element: deal }">
            <article
              class="flex flex-col gap-1 p-3 rounded-lg cursor-grab bg-n-solid-1 outline outline-1 outline-n-weak"
            >
              <span class="truncate text-body-main text-n-slate-12">
                {{ deal.title }}
              </span>
              <span
                v-if="deal.contact.name !== deal.title"
                class="truncate text-label-small text-n-slate-11"
              >
                {{ deal.contact.name }}
              </span>
              <div class="flex items-center justify-between gap-2">
                <span class="text-label-small text-n-slate-12">
                  {{ formatMoney(deal.value_cents, deal.currency) }}
                </span>
                <span class="text-label-small text-n-slate-10">
                  {{ sinceStageChange(deal) }}
                </span>
              </div>
              <router-link
                v-if="deal.conversation_id"
                :to="{
                  name: 'inbox_conversation',
                  params: { conversation_id: deal.conversation_id },
                }"
                class="text-label-small text-n-blue-11 hover:underline"
              >
                {{ $t('SALES_PIPELINE.OPEN_CONVERSATION') }}
              </router-link>
            </article>
          </template>
        </Draggable>
      </div>
    </div>

    <LostReasonDialog
      ref="lostDialogRef"
      @confirm="confirmLost"
      @cancel="cancelLost"
    />
    <StagesDialog
      v-if="pipeline"
      ref="stagesDialogRef"
      :pipeline="pipeline"
      @changed="load"
    />
  </section>
</template>
