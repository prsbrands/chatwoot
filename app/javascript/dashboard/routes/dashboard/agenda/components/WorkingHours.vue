<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgendaAPI from 'dashboard/api/agenda';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// A jornada semanal de uma pessoa: uma faixa por dia, no fuso dela. Segunda
// primeiro, como na grade da Agenda (o dia 0 do backend é domingo).
const props = defineProps({
  userId: { type: Number, required: true },
  availability: { type: Object, default: null },
});
const emit = defineEmits(['saved']);

const { t } = useI18n();
const DAYS = [1, 2, 3, 4, 5, 6, 0];
const WEEKDAY = new Date(2026, 0, 4); // um domingo

const timeZone = ref('');
const days = ref([]);
const isSaving = ref(false);

const dayName = day => {
  const date = new Date(WEEKDAY);
  date.setDate(WEEKDAY.getDate() + day);
  return new Intl.DateTimeFormat(undefined, { weekday: 'long' }).format(date);
};

const load = () => {
  const windows = props.availability?.windows || [];
  timeZone.value =
    props.availability?.time_zone ||
    Intl.DateTimeFormat().resolvedOptions().timeZone;
  days.value = DAYS.map(day => {
    const window = windows.find(item => item.day === day);
    return {
      day,
      on: Boolean(window) || (!props.availability && day >= 1 && day <= 5),
      start: window?.start || '09:00',
      end: window?.end || '18:00',
    };
  });
};

const save = async () => {
  isSaving.value = true;
  try {
    await AgendaAPI.updateAvailability(props.userId, {
      time_zone: timeZone.value.trim(),
      windows: days.value
        .filter(day => day.on)
        .map(({ day, start, end }) => ({ day, start, end })),
    });
    useAlert(t('AGENDA.SETTINGS.HOURS.SAVED'));
    emit('saved');
  } catch (error) {
    useAlert(error.response?.data?.message || t('AGENDA.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

watch(() => [props.userId, props.availability], load, { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-3">
    <Input
      v-model="timeZone"
      :label="$t('AGENDA.SETTINGS.HOURS.TIME_ZONE')"
      :message="$t('AGENDA.SETTINGS.HOURS.TIME_ZONE_HELP')"
    />
    <div
      v-for="item in days"
      :key="item.day"
      class="flex flex-wrap items-center gap-3"
    >
      <Switch v-model="item.on" />
      <span class="w-28 text-sm capitalize text-n-slate-12">
        {{ dayName(item.day) }}
      </span>
      <template v-if="item.on">
        <Input v-model="item.start" type="time" class="w-32" />
        <span class="text-sm text-n-slate-11">–</span>
        <Input v-model="item.end" type="time" class="w-32" />
      </template>
      <span v-else class="text-sm text-n-slate-10">
        {{ $t('AGENDA.SETTINGS.HOURS.OFF') }}
      </span>
    </div>
    <Button
      sm
      class="self-start"
      :label="$t('AGENDA.SETTINGS.HOURS.SAVE')"
      :is-loading="isSaving"
      @click="save"
    />
  </div>
</template>
