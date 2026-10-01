<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// Editor das etapas do funil (so admin). Cada campo salva sozinho ao sair dele;
// a ordem troca nas setas. Ganho e perda sao fixos: um de cada por funil.
const props = defineProps({
  pipeline: { type: Object, required: true },
});
const emit = defineEmits(['changed']);

const { t } = useI18n();
const dialogRef = ref(null);
const stages = ref([]);

const alertError = error =>
  useAlert(error.response?.data?.error || t('SALES_PIPELINE.API.ERROR'));

const open = () => {
  stages.value = props.pipeline.stages.map(stage => ({ ...stage }));
  dialogRef.value.open();
};

const save = async (stage, changes) => {
  try {
    await SalesPipelineAPI.updateStage(props.pipeline.id, stage.id, changes);
    emit('changed');
  } catch (error) {
    alertError(error);
  }
};

const move = async (index, direction) => {
  const list = stages.value;
  const other = index + direction;
  if (other < 0 || other >= list.length) return;
  [list[index], list[other]] = [list[other], list[index]];
  await Promise.all(
    list.map((stage, position) =>
      stage.position === position
        ? null
        : save(stage, { position }).then(() => {
            stage.position = position;
          })
    )
  );
};

const add = async () => {
  // Nova etapa entra antes de ganho e perda.
  const position = stages.value.filter(stage => stage.kind === 'open').length;
  try {
    const { data } = await SalesPipelineAPI.createStage(props.pipeline.id, {
      name: t('SALES_PIPELINE.STAGES.NEW_STAGE'),
      position,
    });
    stages.value.splice(position, 0, data);
    await Promise.all(
      stages.value.map((stage, index) =>
        stage.position === index ? null : save(stage, { position: index })
      )
    );
    emit('changed');
  } catch (error) {
    alertError(error);
  }
};

const remove = async stage => {
  try {
    await SalesPipelineAPI.deleteStage(props.pipeline.id, stage.id);
    stages.value = stages.value.filter(item => item.id !== stage.id);
    emit('changed');
  } catch (error) {
    alertError(error);
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    overflow-y-auto
    :title="$t('SALES_PIPELINE.STAGES.TITLE')"
    :description="$t('SALES_PIPELINE.STAGES.DESCRIPTION')"
    :confirm-button-label="$t('SALES_PIPELINE.STAGES.DONE')"
    :show-cancel-button="false"
    @confirm="dialogRef.close()"
  >
    <div class="flex flex-col gap-2">
      <div
        v-for="(stage, index) in stages"
        :key="stage.id"
        class="flex items-end gap-2 p-2 rounded-lg outline outline-1 outline-n-weak"
      >
        <div class="flex flex-col">
          <Button
            xs
            ghost
            slate
            icon="i-lucide-chevron-up"
            :disabled="index === 0"
            :title="$t('SALES_PIPELINE.STAGES.MOVE_UP')"
            @click="move(index, -1)"
          />
          <Button
            xs
            ghost
            slate
            icon="i-lucide-chevron-down"
            :disabled="index === stages.length - 1"
            :title="$t('SALES_PIPELINE.STAGES.MOVE_DOWN')"
            @click="move(index, 1)"
          />
        </div>
        <Input
          v-model="stage.name"
          class="flex-1"
          :label="$t('SALES_PIPELINE.STAGES.NAME')"
          @blur="save(stage, { name: stage.name })"
        />
        <Input
          v-model="stage.expected_duration_hours"
          type="number"
          class="w-32"
          :label="$t('SALES_PIPELINE.STAGES.EXPECTED_HOURS')"
          @blur="
            save(stage, {
              expected_duration_hours: stage.expected_duration_hours || null,
            })
          "
        />
        <label class="flex flex-col gap-2 text-sm text-n-slate-12 shrink-0">
          {{ $t('SALES_PIPELINE.STAGES.REQUIRES_HUMAN') }}
          <Switch
            :model-value="stage.requires_human"
            @update:model-value="
              value => {
                stage.requires_human = value;
                save(stage, { requires_human: value });
              }
            "
          />
        </label>
        <span
          class="px-2 py-1 mb-1 text-xs rounded-md bg-n-alpha-2 text-n-slate-11 shrink-0"
        >
          {{ $t(`SALES_PIPELINE.STAGES.KIND.${stage.kind}`) }}
        </span>
        <Button
          v-if="stage.kind === 'open'"
          sm
          ghost
          ruby
          icon="i-lucide-trash-2"
          :title="$t('SALES_PIPELINE.STAGES.DELETE')"
          @click="remove(stage)"
        />
      </div>
      <Button
        sm
        faded
        slate
        icon="i-lucide-plus"
        class="self-start"
        :label="$t('SALES_PIPELINE.STAGES.ADD')"
        @click="add"
      />
    </div>
  </Dialog>
</template>
