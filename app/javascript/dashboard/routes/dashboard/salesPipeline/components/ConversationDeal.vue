<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import LostReasonDialog from './LostReasonDialog.vue';
import { useDealFormat } from '../useDealFormat';

// Card do negocio no painel da conversa: o negocio aberto do contato (ou o
// mais recente), com etapa, valor e o historico de quem moveu. Sem negocio,
// o atendente cria um aqui, ligado a esta conversa.
const props = defineProps({
  contactId: { type: Number, default: null },
  conversationId: { type: [Number, String], default: null },
});

const { t } = useI18n();
const { formatMoney } = useDealFormat();

const deal = ref(null);
const stages = ref([]);
const value = ref('');
const isLoading = ref(false);
const lostDialogRef = ref(null);
let pendingStage = null;

const stageOptions = computed(() =>
  stages.value.map(stage => ({ value: stage.id, label: stage.name }))
);
const stageName = id => stages.value.find(stage => stage.id === id)?.name;

const alertError = error =>
  useAlert(error.response?.data?.error || t('SALES_PIPELINE.API.ERROR'));

const show = async id => {
  const { data } = await SalesPipelineAPI.deal(id);
  deal.value = data;
  value.value =
    data.value_cents === null ? '' : String(Math.round(data.value_cents / 100));
};

const load = async () => {
  if (!props.contactId) return;
  isLoading.value = true;
  try {
    const [{ data: pipelines }, { data: deals }] = await Promise.all([
      SalesPipelineAPI.pipelines(),
      SalesPipelineAPI.deals({ contact_id: props.contactId }),
    ]);
    const pipeline =
      pipelines.payload.find(item => item.is_default) || pipelines.payload[0];
    stages.value = pipeline?.stages || [];
    const current =
      deals.payload.find(item => item.status === 'open') || deals.payload[0];
    if (current) await show(current.id);
    else deal.value = null;
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const create = async () => {
  try {
    const { data } = await SalesPipelineAPI.createDeal({
      contact_id: props.contactId,
      conversation_id: props.conversationId,
    });
    deal.value = data;
    useAlert(t('SALES_PIPELINE.CARD.CREATED'));
  } catch (error) {
    alertError(error);
  }
};

const update = async changes => {
  try {
    const { data } = await SalesPipelineAPI.updateDeal(deal.value.id, changes);
    deal.value = data;
  } catch (error) {
    alertError(error);
    await show(deal.value.id);
  }
};

const changeStage = stageId => {
  const stage = stages.value.find(item => item.id === stageId);
  if (stage.kind === 'lost') {
    pendingStage = stage;
    lostDialogRef.value.open(stage.name);
    return;
  }
  update({ stage_id: stageId });
};

const saveValue = () => {
  const number = Number(value.value);
  const cents = value.value === '' ? null : Math.round(number * 100);
  if (cents === deal.value.value_cents) return;
  update({ value_cents: cents });
};

watch(() => props.contactId, load, { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-3 px-4 py-3">
    <template v-if="deal">
      <div class="flex items-center justify-between gap-2">
        <span class="truncate text-body-main text-n-slate-12">
          {{ deal.title }}
        </span>
        <span
          class="px-2 py-0.5 text-label-small rounded-md bg-n-alpha-2 text-n-slate-11"
        >
          {{ $t(`SALES_PIPELINE.STATUS.${deal.status}`) }}
        </span>
      </div>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('SALES_PIPELINE.CARD.STAGE') }}
        <Select
          :model-value="deal.stage_id"
          :options="stageOptions"
          @update:model-value="changeStage"
        />
      </label>
      <Input
        v-model="value"
        type="number"
        :label="`${$t('SALES_PIPELINE.CARD.VALUE')} (${deal.currency})`"
        @blur="saveValue"
      />
      <p v-if="deal.lost_reason" class="text-label-small text-n-ruby-11">
        {{ deal.lost_reason }}
      </p>
      <div v-if="deal.transitions?.length" class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ $t('SALES_PIPELINE.CARD.HISTORY') }}
        </span>
        <span
          v-for="transition in deal.transitions.slice(0, 5)"
          :key="transition.id"
          class="text-label-small text-n-slate-12"
        >
          {{
            $t(`SALES_PIPELINE.CARD.MOVED_BY.${transition.actor_type}`, {
              name: transition.actor_name,
              stage: stageName(transition.to_stage_id),
            })
          }}
          <template v-if="transition.reason">
            — {{ transition.reason }}
          </template>
        </span>
      </div>
      <span v-if="deal.value_cents" class="text-label-small text-n-slate-11">
        {{ formatMoney(deal.value_cents, deal.currency) }}
      </span>
      <router-link
        :to="{ name: 'sales_pipeline_index' }"
        class="text-label-small text-n-blue-11 hover:underline"
      >
        {{ $t('SALES_PIPELINE.CARD.OPEN_PIPELINE') }}
      </router-link>
    </template>
    <template v-else-if="!isLoading">
      <p class="text-body-main text-n-slate-11">
        {{ $t('SALES_PIPELINE.CARD.NONE') }}
      </p>
      <Button
        sm
        faded
        blue
        icon="i-lucide-plus"
        class="self-start"
        :label="$t('SALES_PIPELINE.CARD.CREATE')"
        @click="create"
      />
    </template>
    <LostReasonDialog
      ref="lostDialogRef"
      @confirm="
        reason => update({ stage_id: pendingStage.id, lost_reason: reason })
      "
      @cancel="pendingStage = null"
    />
  </div>
</template>
