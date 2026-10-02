<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import AgendaAPI from 'dashboard/api/agenda';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Criar ou editar um tipo de agendamento.
const emit = defineEmits(['saved']);

const { t } = useI18n();
const agents = useMapGetter('agents/getAgents');

const NOBODY = 0;
const DEFAULTS = {
  name: '',
  duration_minutes: 60,
  buffer_before_minutes: 0,
  buffer_after_minutes: 0,
  minimum_notice_minutes: 120,
  booking_window_days: 60,
  location: '',
  default_owner_id: NOBODY,
  requires_confirmation: false,
  active: true,
  ai_bookable: false,
  remind: false,
  reminder_hours: 24,
  reminder_message: '',
  google_meet: false,
  booked_stage_id: 0,
  no_show_message: '',
};

// Os marcadores do lembrete são do backend (Agenda::ReminderJob); passados
// como parâmetros, o vue-i18n os devolve literais em vez de apagá-los.
const PLACEHOLDERS = {
  name: '{name}',
  date: '{date}',
  time: '{time}',
  type: '{type}',
  link: '{link}',
};

const dialogRef = ref(null);
const eventTypeId = ref(null);
const form = ref({ ...DEFAULTS });
const isSaving = ref(false);

// Etapas dos funis para "ao marcar, mover o negócio para". Conta sem funil
// (a API recusa) fica sem a opção.
const pipelines = ref([]);
const stageOptions = computed(() => [
  { value: 0, label: t('AGENDA.SETTINGS.TYPE.NO_STAGE') },
  ...pipelines.value.flatMap(pipeline =>
    pipeline.stages
      .filter(stage => stage.kind === 'open')
      .map(stage => ({
        value: stage.id,
        label:
          pipelines.value.length > 1
            ? `${pipeline.name} · ${stage.name}`
            : stage.name,
      }))
  ),
]);

const ownerOptions = computed(() => [
  { value: NOBODY, label: t('AGENDA.SETTINGS.TYPE.NO_DEFAULT_OWNER') },
  ...agents.value.map(agent => ({ value: agent.id, label: agent.name })),
]);

const open = (eventType = null) => {
  eventTypeId.value = eventType?.id || null;
  form.value = {
    ...DEFAULTS,
    ...(eventType || {}),
    default_owner_id: eventType?.default_owner_id || NOBODY,
    location: eventType?.location || '',
    remind: Boolean(eventType?.reminder_minutes_before),
    reminder_hours: eventType?.reminder_minutes_before
      ? eventType.reminder_minutes_before / 60
      : 24,
    reminder_message:
      eventType?.reminder_message ||
      t('AGENDA.SETTINGS.TYPE.REMINDER_DEFAULT', PLACEHOLDERS),
    booked_stage_id: eventType?.booked_stage_id || 0,
    no_show_message: eventType?.no_show_message || '',
  };
  dialogRef.value.open();
  SalesPipelineAPI.pipelines()
    .then(({ data }) => {
      pipelines.value = data.payload;
    })
    .catch(() => {
      pipelines.value = [];
    });
};

const save = async () => {
  const { remind, reminder_hours: hours, ...fields } = form.value;
  const payload = {
    ...fields,
    name: fields.name.trim(),
    default_owner_id: fields.default_owner_id || null,
    reminder_minutes_before: remind ? Math.round(hours * 60) : null,
    reminder_message: remind ? fields.reminder_message.trim() : null,
    booked_stage_id: fields.booked_stage_id || null,
    no_show_message: fields.no_show_message.trim() || null,
  };
  isSaving.value = true;
  try {
    if (eventTypeId.value) {
      await AgendaAPI.updateEventType(eventTypeId.value, payload);
    } else {
      await AgendaAPI.createEventType(payload);
    }
    emit('saved');
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.response?.data?.message || t('AGENDA.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    :title="
      eventTypeId
        ? $t('AGENDA.SETTINGS.TYPE.EDIT')
        : $t('AGENDA.SETTINGS.TYPE.NEW')
    "
    :confirm-button-label="$t('AGENDA.DIALOG.SAVE')"
    :disable-confirm-button="!form.name.trim()"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <Input
        v-model="form.name"
        :label="$t('AGENDA.SETTINGS.TYPE.NAME')"
        :placeholder="$t('AGENDA.SETTINGS.TYPE.NAME_PLACEHOLDER')"
      />
      <div class="grid grid-cols-3 gap-3">
        <Input
          v-model.number="form.duration_minutes"
          type="number"
          :label="$t('AGENDA.SETTINGS.TYPE.DURATION')"
        />
        <Input
          v-model.number="form.buffer_before_minutes"
          type="number"
          :label="$t('AGENDA.SETTINGS.TYPE.BUFFER_BEFORE')"
        />
        <Input
          v-model.number="form.buffer_after_minutes"
          type="number"
          :label="$t('AGENDA.SETTINGS.TYPE.BUFFER_AFTER')"
        />
      </div>
      <div class="grid grid-cols-2 gap-3">
        <Input
          v-model.number="form.minimum_notice_minutes"
          type="number"
          :label="$t('AGENDA.SETTINGS.TYPE.NOTICE')"
        />
        <Input
          v-model.number="form.booking_window_days"
          type="number"
          :label="$t('AGENDA.SETTINGS.TYPE.WINDOW')"
        />
      </div>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('AGENDA.SETTINGS.TYPE.DEFAULT_OWNER') }}
        <Select v-model="form.default_owner_id" :options="ownerOptions" />
      </label>
      <Input
        v-model="form.location"
        :label="$t('AGENDA.DIALOG.LOCATION')"
        :placeholder="$t('AGENDA.DIALOG.LOCATION_PLACEHOLDER')"
      />
      <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
        {{ $t('AGENDA.SETTINGS.TYPE.REQUIRES_CONFIRMATION') }}
        <Switch v-model="form.requires_confirmation" />
      </label>
      <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
        {{ $t('AGENDA.SETTINGS.TYPE.ACTIVE') }}
        <Switch v-model="form.active" />
      </label>
      <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
        <span class="flex flex-col">
          {{ $t('AGENDA.SETTINGS.TYPE.AI_BOOKABLE') }}
          <span class="text-xs text-n-slate-11">
            {{ $t('AGENDA.SETTINGS.TYPE.AI_BOOKABLE_HELP') }}
          </span>
        </span>
        <Switch v-model="form.ai_bookable" />
      </label>
      <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
        <span class="flex flex-col">
          {{ $t('AGENDA.SETTINGS.TYPE.GOOGLE_MEET') }}
          <span class="text-xs text-n-slate-11">
            {{ $t('AGENDA.SETTINGS.TYPE.GOOGLE_MEET_HELP') }}
          </span>
        </span>
        <Switch v-model="form.google_meet" />
      </label>
      <label
        v-if="pipelines.length"
        class="flex flex-col gap-1 text-label-small text-n-slate-11"
      >
        {{ $t('AGENDA.SETTINGS.TYPE.BOOKED_STAGE') }}
        <Select v-model="form.booked_stage_id" :options="stageOptions" />
      </label>
      <label class="flex items-center justify-between gap-3 text-sm text-n-slate-12">
        <span class="flex flex-col">
          {{ $t('AGENDA.SETTINGS.TYPE.REMIND') }}
          <span class="text-xs text-n-slate-11">
            {{ $t('AGENDA.SETTINGS.TYPE.REMIND_HELP') }}
          </span>
        </span>
        <Switch v-model="form.remind" />
      </label>
      <template v-if="form.remind">
        <Input
          v-model.number="form.reminder_hours"
          type="number"
          :label="$t('AGENDA.SETTINGS.TYPE.REMINDER_HOURS')"
        />
        <TextArea
          v-model="form.reminder_message"
          :label="$t('AGENDA.SETTINGS.TYPE.REMINDER_MESSAGE')"
          :message="$t('AGENDA.SETTINGS.TYPE.REMINDER_MESSAGE_HELP', PLACEHOLDERS)"
          :max-length="1000"
        />
      </template>
      <TextArea
        v-model="form.no_show_message"
        :label="$t('AGENDA.SETTINGS.TYPE.NO_SHOW_MESSAGE')"
        :message="$t('AGENDA.SETTINGS.TYPE.NO_SHOW_MESSAGE_HELP', PLACEHOLDERS)"
        :placeholder="$t('AGENDA.SETTINGS.TYPE.NO_SHOW_DEFAULT', PLACEHOLDERS)"
        :max-length="1000"
      />
    </div>
  </Dialog>
</template>
