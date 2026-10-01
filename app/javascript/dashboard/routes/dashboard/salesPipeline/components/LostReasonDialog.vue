<script setup>
import { ref } from 'vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

// Ir para a etapa de perda fecha o negocio e exige o motivo (Sales::Deal
// valida). Quem chama recebe o motivo em `confirm` ou desfaz em `cancel`.
const emit = defineEmits(['confirm', 'cancel']);

const dialogRef = ref(null);
const stageName = ref('');
const reason = ref('');
let confirmed = false;

const open = name => {
  stageName.value = name;
  reason.value = '';
  confirmed = false;
  dialogRef.value.open();
};

const confirm = () => {
  confirmed = true;
  emit('confirm', reason.value.trim());
  dialogRef.value.close();
};

const onClose = () => {
  if (!confirmed) emit('cancel');
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="$t('SALES_PIPELINE.LOST_DIALOG.TITLE')"
    :description="
      $t('SALES_PIPELINE.LOST_DIALOG.DESCRIPTION', { stage: stageName })
    "
    :confirm-button-label="$t('SALES_PIPELINE.LOST_DIALOG.CONFIRM')"
    :disable-confirm-button="!reason.trim()"
    @confirm="confirm"
    @close="onClose"
  >
    <Input
      v-model="reason"
      :label="$t('SALES_PIPELINE.LOST_DIALOG.LABEL')"
      :placeholder="$t('SALES_PIPELINE.LOST_DIALOG.PLACEHOLDER')"
    />
  </Dialog>
</template>
