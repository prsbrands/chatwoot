<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import AgendaAPI from 'dashboard/api/agenda';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

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
};

const dialogRef = ref(null);
const eventTypeId = ref(null);
const form = ref({ ...DEFAULTS });
const isSaving = ref(false);

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
  };
  dialogRef.value.open();
};

const save = async () => {
  const payload = {
    ...form.value,
    name: form.value.name.trim(),
    default_owner_id: form.value.default_owner_id || null,
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
    </div>
  </Dialog>
</template>
