<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { OUTCOMES } from '../constants';

// Resolver (com desfecho) ou cancelar um caso, com o texto do que foi feito.
const emit = defineEmits(['confirm']);

const { t } = useI18n();
const dialogRef = ref(null);
const action = ref('resolve');
const outcome = ref('solved');
const resolution = ref('');

const outcomeOptions = computed(() =>
  OUTCOMES.map(value => ({ value, label: t(`CASES.OUTCOME.${value}`) }))
);

const open = nextAction => {
  action.value = nextAction;
  outcome.value = 'solved';
  resolution.value = '';
  dialogRef.value.open();
};

const confirm = () => {
  emit('confirm', action.value, {
    outcome: action.value === 'resolve' ? outcome.value : undefined,
    resolution: resolution.value.trim() || undefined,
  });
  dialogRef.value.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t(`CASES.ACTIONS.${action}`)"
    :confirm-button-label="$t(`CASES.ACTIONS.${action}`)"
    @confirm="confirm"
  >
    <div class="flex flex-col gap-3">
      <label
        v-if="action === 'resolve'"
        class="flex flex-col gap-1 text-label-small text-n-slate-11"
      >
        {{ $t('CASES.OUTCOME_LABEL') }}
        <Select v-model="outcome" :options="outcomeOptions" />
      </label>
      <TextArea
        v-model="resolution"
        :label="
          action === 'resolve'
            ? $t('CASES.RESOLUTION')
            : $t('CASES.CANCEL_REASON')
        "
        :max-length="5000"
      />
    </div>
  </Dialog>
</template>
