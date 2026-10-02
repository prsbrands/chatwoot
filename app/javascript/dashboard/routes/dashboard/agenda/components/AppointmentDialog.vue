<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import AgendaAPI from 'dashboard/api/agenda';
import ContactAPI from 'dashboard/api/contacts';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Marcar ou editar um compromisso. Aberto de um negócio, já vem com ele e o
// contato; da grade, com a hora clicada. Editando, mostra as ações do status
// (confirmar, realizado, não compareceu, cancelar) e excluir.
const emit = defineEmits(['saved']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');

const DURATIONS = [15, 30, 45, 60, 90, 120];
const STATUS_ACTIONS = ['confirmed', 'completed', 'no_show', 'cancelled'];

const dialogRef = ref(null);
const appointment = ref(null);
const links = ref({});
const title = ref('');
const starts = ref('');
const duration = ref(60);
const ownerId = ref(null);
const location = ref('');
const notes = ref('');
const contact = ref(null);
const contactQuery = ref('');
const contactResults = ref([]);
const isSaving = ref(false);
const NO_TYPE = 0;
const eventTypes = ref([]);
const eventTypeId = ref(NO_TYPE);
const slots = ref([]);
const googleUnavailable = ref(false);

const typeOptions = computed(() => [
  { value: NO_TYPE, label: t('AGENDA.DIALOG.NO_TYPE') },
  ...eventTypes.value
    .filter(item => item.active || item.id === eventTypeId.value)
    .map(item => ({ value: item.id, label: item.name })),
]);
const selectedType = computed(() =>
  eventTypes.value.find(item => item.id === eventTypeId.value)
);

const ownerOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);
const durationOptions = computed(() => {
  const options = DURATIONS.map(minutes => ({
    value: minutes,
    label: t('AGENDA.DIALOG.MINUTES', { minutes }),
  }));
  // Compromisso vindo do Google ou editado com outra duração continua valendo.
  if (!DURATIONS.includes(duration.value)) {
    options.push({
      value: duration.value,
      label: t('AGENDA.DIALOG.MINUTES', { minutes: duration.value }),
    });
  }
  return options;
});

const pad = number => String(number).padStart(2, '0');
const toLocalInput = date =>
  `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;

const open = ({
  appointment: existing = null,
  startsAt = null,
  dealId = null,
  contact: presetContact = null,
  conversationId = null,
  title: presetTitle = '',
} = {}) => {
  appointment.value = existing;
  links.value = existing
    ? {}
    : { deal_id: dealId, conversation_id: conversationId };
  title.value = existing?.title || presetTitle;
  const start = existing
    ? new Date(existing.starts_at * 1000)
    : startsAt || new Date();
  starts.value = toLocalInput(start);
  duration.value = existing
    ? Math.round((existing.ends_at - existing.starts_at) / 60)
    : 60;
  ownerId.value = existing?.owner?.id || currentUser.value.id;
  location.value = existing?.location || '';
  notes.value = existing?.notes || '';
  contact.value = existing?.contact || presetContact;
  contactQuery.value = '';
  contactResults.value = [];
  eventTypeId.value = existing?.event_type_id || NO_TYPE;
  slots.value = [];
  dialogRef.value.open();
  AgendaAPI.eventTypes().then(({ data }) => {
    eventTypes.value = data.payload;
  });
};

// O tipo traz a duração, o local e quem atende por padrão.
const pickType = id => {
  eventTypeId.value = id;
  const type = selectedType.value;
  if (!type) return;
  duration.value = type.duration_minutes;
  if (!location.value) location.value = type.location || '';
  if (!appointment.value && type.default_owner_id) {
    ownerId.value = type.default_owner_id;
  }
};

// Horários livres do dia escolhido, para o tipo e a pessoa.
const startDate = computed(() => starts.value.slice(0, 10));
const loadSlots = async () => {
  slots.value = [];
  if (!selectedType.value || !startDate.value || !ownerId.value) return;
  const { data } = await AgendaAPI.freeSlots({
    event_type_id: eventTypeId.value,
    owner_id: ownerId.value,
    date: startDate.value,
  });
  slots.value = data.slots;
  googleUnavailable.value = data.google_unavailable;
};
watch([eventTypeId, ownerId, startDate], loadSlots);

const slotLabel = epoch =>
  new Intl.DateTimeFormat(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(epoch * 1000));
const pickSlot = epoch => {
  starts.value = toLocalInput(new Date(epoch * 1000));
};
const isPicked = epoch =>
  starts.value === toLocalInput(new Date(epoch * 1000));

let searchTimer = null;
watch(contactQuery, query => {
  clearTimeout(searchTimer);
  if (query.trim().length < 2) {
    contactResults.value = [];
    return;
  }
  searchTimer = setTimeout(async () => {
    const { data } = await ContactAPI.search(query.trim());
    contactResults.value = data.payload.slice(0, 6);
  }, 300);
});

const pickContact = item => {
  contact.value = { id: item.id, name: item.name };
  contactQuery.value = '';
  contactResults.value = [];
};

const request = async payload => {
  isSaving.value = true;
  try {
    const { data } = appointment.value
      ? await AgendaAPI.updateAppointment(appointment.value.id, payload)
      : await AgendaAPI.createAppointment(payload);
    emit('saved', data);
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.response?.data?.error || t('AGENDA.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const save = () => {
  const start = new Date(starts.value);
  request({
    ...links.value,
    title: title.value.trim(),
    starts_at: start.toISOString(),
    ends_at: new Date(start.getTime() + duration.value * 60000).toISOString(),
    owner_id: ownerId.value,
    event_type_id: eventTypeId.value || null,
    contact_id: contact.value?.id || null,
    location: location.value.trim(),
    notes: notes.value.trim(),
  });
};

const setStatus = status => request({ status });

const remove = async () => {
  try {
    await AgendaAPI.deleteAppointment(appointment.value.id);
    emit('saved');
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.response?.data?.error || t('AGENDA.ERROR'));
  }
};

onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
});

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      appointment ? $t('AGENDA.DIALOG.EDIT') : $t('AGENDA.DIALOG.NEW')
    "
    :confirm-button-label="$t('AGENDA.DIALOG.SAVE')"
    :disable-confirm-button="!title.trim() || !starts"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <div
        v-if="appointment"
        class="flex flex-wrap items-center gap-2 pb-3 border-b border-n-weak"
      >
        <span class="text-xs text-n-slate-11">
          {{ $t(`AGENDA.STATUS.${appointment.status}`) }}
        </span>
        <Button
          v-for="status in STATUS_ACTIONS.filter(
            item => item !== appointment.status
          )"
          :key="status"
          xs
          faded
          :ruby="status === 'cancelled' || status === 'no_show'"
          :slate="status !== 'cancelled' && status !== 'no_show'"
          :label="$t(`AGENDA.ACTION.${status}`)"
          @click="setStatus(status)"
        />
        <Button
          xs
          ghost
          ruby
          icon="i-lucide-trash-2"
          :label="$t('AGENDA.DIALOG.DELETE')"
          @click="remove"
        />
      </div>
      <Input
        v-model="title"
        :label="$t('AGENDA.DIALOG.TITLE')"
        :placeholder="$t('AGENDA.DIALOG.TITLE_PLACEHOLDER')"
      />
      <label
        v-if="eventTypes.length"
        class="flex flex-col gap-1 text-label-small text-n-slate-11"
      >
        {{ $t('AGENDA.DIALOG.TYPE') }}
        <Select
          :model-value="eventTypeId"
          :options="typeOptions"
          @update:model-value="pickType"
        />
      </label>
      <div class="grid grid-cols-2 gap-3">
        <Input
          v-model="starts"
          type="datetime-local"
          :label="$t('AGENDA.DIALOG.STARTS')"
        />
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('AGENDA.DIALOG.DURATION') }}
          <Select v-model="duration" :options="durationOptions" />
        </label>
      </div>
      <div v-if="selectedType" class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ $t('AGENDA.DIALOG.FREE_SLOTS') }}
        </span>
        <div v-if="slots.length" class="flex flex-wrap gap-1">
          <Button
            v-for="slot in slots"
            :key="slot"
            xs
            :faded="!isPicked(slot)"
            :slate="!isPicked(slot)"
            :label="slotLabel(slot)"
            @click="pickSlot(slot)"
          />
        </div>
        <span v-else class="text-xs text-n-slate-10">
          {{ $t('AGENDA.DIALOG.NO_FREE_SLOTS') }}
        </span>
        <span v-if="googleUnavailable" class="text-xs text-n-amber-11">
          {{ $t('AGENDA.DIALOG.GOOGLE_UNAVAILABLE') }}
        </span>
      </div>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('AGENDA.DIALOG.OWNER') }}
        <Select v-model="ownerId" :options="ownerOptions" />
      </label>
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ $t('AGENDA.DIALOG.CONTACT') }}
        </span>
        <div v-if="contact" class="flex items-center gap-2">
          <span class="text-sm text-n-slate-12">{{ contact.name }}</span>
          <Button
            xs
            ghost
            slate
            icon="i-lucide-x"
            :title="$t('AGENDA.DIALOG.REMOVE_CONTACT')"
            @click="contact = null"
          />
        </div>
        <template v-else>
          <Input
            v-model="contactQuery"
            :placeholder="$t('AGENDA.DIALOG.CONTACT_PLACEHOLDER')"
          />
          <div v-if="contactResults.length" class="flex flex-wrap gap-1">
            <Button
              v-for="item in contactResults"
              :key="item.id"
              xs
              slate
              faded
              :label="item.name || item.phone_number || item.email"
              @click="pickContact(item)"
            />
          </div>
        </template>
      </div>
      <Input
        v-model="location"
        :label="$t('AGENDA.DIALOG.LOCATION')"
        :placeholder="$t('AGENDA.DIALOG.LOCATION_PLACEHOLDER')"
      />
      <TextArea
        v-model="notes"
        :label="$t('AGENDA.DIALOG.NOTES')"
        :max-length="2000"
      />
    </div>
  </Dialog>
</template>
