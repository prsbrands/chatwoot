<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useLocale } from 'shared/composables/useLocale';
import AgendaAPI from 'dashboard/api/agenda';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import AppointmentDialog from '../components/AppointmentDialog.vue';
import GoogleConnectionCard from '../components/GoogleConnectionCard.vue';

// O que está marcado, com quem e quem atende — seu e da equipe. Grade de dia
// ou semana (segunda a domingo) no fuso do navegador; o ocupado do Google de
// cada responsável aparece cinza por trás dos compromissos.
const { t } = useI18n();
const store = useStore();
const { resolvedLocale } = useLocale();
const agents = useMapGetter('agents/getAgents');

const HOUR_REM = 3;
const FIRST_VISIBLE_HOUR = 7;
const SLOT_MINUTES = 30;
const DAY_MS = 86400000;
const HOURS = Array.from({ length: 24 }, (_, hour) => hour);
const STATUS_CLASSES = {
  pending:
    'bg-n-amber-3 text-n-amber-12 outline-dashed outline-1 outline-n-amber-7',
  confirmed: 'bg-n-blue-3 text-n-blue-12 outline outline-1 outline-n-blue-6',
  completed: 'bg-n-teal-3 text-n-teal-12 outline outline-1 outline-n-teal-6',
  no_show: 'bg-n-ruby-3 text-n-ruby-12 line-through',
  cancelled: 'bg-n-slate-3 text-n-slate-10 line-through',
};

const view = ref('week');
const anchor = ref(new Date());
const owner = ref('me');
const appointments = ref([]);
const busy = ref([]);
const googleErrors = ref([]);
const gridRef = ref(null);
const dialogRef = ref(null);
const now = ref(Date.now());

const startOfDay = date => {
  const day = new Date(date);
  day.setHours(0, 0, 0, 0);
  return day;
};

const days = computed(() => {
  const first = startOfDay(anchor.value);
  if (view.value === 'week') {
    // Segunda-feira da semana do dia âncora.
    first.setDate(first.getDate() - ((first.getDay() + 6) % 7));
  }
  const count = view.value === 'week' ? 7 : 1;
  return Array.from({ length: count }, (_, index) => {
    const day = new Date(first);
    day.setDate(first.getDate() + index);
    return day;
  });
});
const rangeEnd = computed(() => {
  const end = new Date(days.value[days.value.length - 1]);
  end.setDate(end.getDate() + 1);
  return end;
});

const ownerOptions = computed(() => [
  { value: 'me', label: t('AGENDA.OWNER.me') },
  { value: 'all', label: t('AGENDA.OWNER.all') },
  ...agents.value.map(agent => ({ value: String(agent.id), label: agent.name })),
]);

const fetchAgenda = async () => {
  const { data } = await AgendaAPI.appointments({
    from: days.value[0].toISOString(),
    to: rangeEnd.value.toISOString(),
    owner_id: owner.value,
  });
  appointments.value = data.payload;
  busy.value = data.busy;
  googleErrors.value = data.google_errors;
};

const format = (date, options) =>
  new Intl.DateTimeFormat(resolvedLocale.value, options).format(date);
const timeOf = epoch =>
  format(new Date(epoch * 1000), { hour: '2-digit', minute: '2-digit' });
const title = computed(() =>
  view.value === 'week'
    ? `${format(days.value[0], { day: 'numeric', month: 'short' })} – ${format(days.value[6], { day: 'numeric', month: 'short', year: 'numeric' })}`
    : format(days.value[0], { dateStyle: 'full' })
);
const isToday = day => startOfDay(new Date()).getTime() === day.getTime();

// Minutos desde a meia-noite do dia, cortados nas bordas (compromisso que
// atravessa a meia-noite aparece nos dois dias).
const minutesIn = (day, epoch) =>
  Math.min(Math.max((epoch * 1000 - day.getTime()) / 60000, 0), 1440);

// Compromissos que se sobrepõem dividem a largura: cada grupo encadeado de
// sobreposições ganha tantas faixas quantas precisar.
const layoutDay = items => {
  const sorted = [...items].sort((a, b) => a.top - b.top);
  const placed = [];
  let cluster = [];
  let clusterEnd = -1;
  const closeCluster = () => {
    const lanes = Math.max(...cluster.map(item => item.lane)) + 1;
    cluster.forEach(item => placed.push({ ...item, lanes }));
    cluster = [];
  };
  sorted.forEach(item => {
    if (cluster.length && item.top >= clusterEnd) closeCluster();
    const laneEnds = [];
    cluster.forEach(other => {
      laneEnds[other.lane] = Math.max(laneEnds[other.lane] ?? 0, other.bottom);
    });
    let lane = laneEnds.findIndex(end => end <= item.top);
    if (lane === -1) lane = laneEnds.length;
    cluster.push({ ...item, lane });
    clusterEnd = Math.max(clusterEnd, item.bottom);
  });
  if (cluster.length) closeCluster();
  return placed;
};

const columns = computed(() =>
  days.value.map(day => {
    const dayStart = day.getTime() / 1000;
    const dayEnd = dayStart + DAY_MS / 1000;
    const inDay = item => item.starts_at < dayEnd && item.ends_at > dayStart;
    const span = item => ({
      top: minutesIn(day, item.starts_at),
      bottom: Math.max(
        minutesIn(day, item.ends_at),
        minutesIn(day, item.starts_at) + 15
      ),
    });
    return {
      day,
      appointments: layoutDay(
        appointments.value
          .filter(inDay)
          .map(appointment => ({ appointment, ...span(appointment) }))
      ),
      busy: busy.value
        .filter(block => !block.all_day && inDay(block))
        .map(block => ({ block, ...span(block) })),
      allDayBusy: busy.value.some(block => block.all_day && inDay(block)),
      nowTop: isToday(day) ? minutesIn(day, now.value / 1000) : null,
    };
  })
);

// Posição e altura dependem da hora: não há classe utilitária para isso, por
// isso o style (como a cor das etiquetas no menu do Chatwoot).
const blockStyle = ({ top, bottom, lane = 0, lanes = 1 }) => ({
  top: `${(top / 60) * HOUR_REM}rem`,
  height: `${((bottom - top) / 60) * HOUR_REM}rem`,
  left: `${(lane / lanes) * 100}%`,
  width: `${100 / lanes}%`,
});

const move = direction => {
  const date = new Date(anchor.value);
  date.setDate(date.getDate() + direction * (view.value === 'week' ? 7 : 1));
  anchor.value = date;
};

// Clique num horário vazio marca ali, arredondado para a meia hora.
const newAt = (day, event) => {
  const { top, height } = event.currentTarget.getBoundingClientRect();
  const minutes = ((event.clientY - top) / height) * 1440;
  const start = new Date(day);
  start.setMinutes(Math.floor(minutes / SLOT_MINUTES) * SLOT_MINUTES);
  dialogRef.value.open({ startsAt: start });
};

const newAppointment = () => {
  const start = new Date();
  start.setMinutes(Math.ceil(start.getMinutes() / SLOT_MINUTES) * SLOT_MINUTES, 0, 0);
  dialogRef.value.open({ startsAt: start });
};

let clock = null;
watch([days, owner], fetchAgenda);
onMounted(async () => {
  if (!agents.value.length) store.dispatch('agents/get');
  await fetchAgenda();
  await nextTick();
  gridRef.value?.scrollTo({
    top: (gridRef.value.scrollHeight / 24) * FIRST_VISIBLE_HOUR,
  });
  clock = setInterval(() => {
    now.value = Date.now();
  }, 60000);
});
onBeforeUnmount(() => clearInterval(clock));
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 py-4 border-b border-n-weak"
    >
      <div class="flex flex-wrap items-center gap-2 min-w-0">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('AGENDA.HEADER') }}
        </h1>
        <Button xs slate faded icon="i-lucide-chevron-left" @click="move(-1)" />
        <Button
          xs
          slate
          faded
          :label="$t('AGENDA.TODAY')"
          @click="anchor = new Date()"
        />
        <Button xs slate faded icon="i-lucide-chevron-right" @click="move(1)" />
        <span class="text-sm text-n-slate-12">{{ title }}</span>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Button
          v-for="option in ['day', 'week']"
          :key="option"
          xs
          :slate="view !== option"
          :faded="view !== option"
          :label="$t(`AGENDA.VIEW.${option}`)"
          @click="view = option"
        />
        <Select v-model="owner" :options="ownerOptions" />
        <Button
          sm
          icon="i-lucide-plus"
          :label="$t('AGENDA.NEW')"
          @click="newAppointment"
        />
      </div>
    </header>

    <div class="flex flex-col gap-2 px-6 pt-4">
      <GoogleConnectionCard @changed="fetchAgenda" />
      <p
        v-if="googleErrors.length"
        class="px-3 py-2 text-xs rounded-lg bg-n-amber-3 text-n-amber-11"
      >
        {{ $t('AGENDA.GOOGLE.READ_ERROR', { count: googleErrors.length }) }}
      </p>
    </div>

    <div class="flex px-6 pt-3 ms-14">
      <div
        v-for="column in columns"
        :key="column.day.getTime()"
        class="flex flex-col items-center flex-1 min-w-0 pb-2"
      >
        <span class="text-xs uppercase text-n-slate-11">
          {{ format(column.day, { weekday: 'short' }) }}
        </span>
        <span
          class="flex items-center justify-center text-sm rounded-full size-7"
          :class="
            isToday(column.day) ? 'bg-n-brand text-white' : 'text-n-slate-12'
          "
        >
          {{ column.day.getDate() }}
        </span>
        <span v-if="column.allDayBusy" class="text-xs text-n-slate-10">
          {{ $t('AGENDA.ALL_DAY_BUSY') }}
        </span>
      </div>
    </div>

    <div ref="gridRef" class="flex-1 px-6 pb-6 overflow-y-auto">
      <div class="flex">
        <div class="flex flex-col w-14 shrink-0">
          <span
            v-for="hour in HOURS"
            :key="hour"
            class="h-12 pe-2 text-xs text-end text-n-slate-10 -translate-y-2"
          >
            {{ hour ? `${String(hour).padStart(2, '0')}:00` : '' }}
          </span>
        </div>
        <div
          v-for="column in columns"
          :key="column.day.getTime()"
          class="relative flex-1 min-w-0 border-s border-n-weak cursor-pointer"
          @click.self="newAt(column.day, $event)"
        >
          <div
            v-for="hour in HOURS"
            :key="hour"
            class="h-12 border-t border-n-weak pointer-events-none"
          />
          <div
            v-for="(item, index) in column.busy"
            :key="`busy-${index}`"
            class="absolute px-1 text-xs rounded pointer-events-none bg-n-alpha-2 text-n-slate-10"
            :style="blockStyle(item)"
          >
            {{ $t('AGENDA.BUSY') }}
          </div>
          <button
            v-for="item in column.appointments"
            :key="item.appointment.id"
            type="button"
            class="absolute flex flex-col overflow-hidden text-xs text-start rounded-md px-1.5 py-1 border border-n-solid-1"
            :class="STATUS_CLASSES[item.appointment.status]"
            :style="blockStyle(item)"
            @click="dialogRef.open({ appointment: item.appointment })"
          >
            <span class="font-medium truncate">
              {{ item.appointment.title }}
            </span>
            <span class="truncate">
              {{ timeOf(item.appointment.starts_at) }}
              <template v-if="item.appointment.contact">
                · {{ item.appointment.contact.name }}
              </template>
            </span>
            <span v-if="owner !== 'me'" class="truncate opacity-80">
              {{ item.appointment.owner?.name }}
            </span>
          </button>
          <div
            v-if="column.nowTop !== null"
            class="absolute inset-x-0 h-px pointer-events-none bg-n-ruby-9"
            :style="{ top: `${(column.nowTop / 60) * HOUR_REM}rem` }"
          />
        </div>
      </div>
    </div>

    <AppointmentDialog ref="dialogRef" @saved="fetchAgenda" />
  </section>
</template>
