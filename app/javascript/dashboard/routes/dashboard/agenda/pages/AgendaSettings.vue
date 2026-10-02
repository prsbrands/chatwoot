<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import AgendaAPI from 'dashboard/api/agenda';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import EventTypeDialog from '../components/EventTypeDialog.vue';
import WorkingHours from '../components/WorkingHours.vue';

// Tipos de agendamento (admin) e a jornada de cada pessoa (a própria, ou de
// qualquer um para o admin). Os dois juntos dizem os horários livres.
const { t } = useI18n();
const store = useStore();
const { isAdmin } = useAdmin();
const agents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');

const eventTypes = ref([]);
const availabilities = ref([]);
const personId = ref(null);
const typeDialogRef = ref(null);

const personOptions = computed(() =>
  (isAdmin.value
    ? agents.value
    : agents.value.filter(agent => agent.id === currentUser.value.id)
  ).map(agent => ({ value: agent.id, label: agent.name }))
);
const personAvailability = computed(() =>
  availabilities.value.find(item => item.user_id === personId.value)
);
const ownerName = id => agents.value.find(agent => agent.id === id)?.name;

const load = async () => {
  const [{ data: types }, { data: hours }] = await Promise.all([
    AgendaAPI.eventTypes(),
    AgendaAPI.availabilities(),
  ]);
  eventTypes.value = types.payload;
  availabilities.value = hours.payload;
};

const remove = async eventType => {
  try {
    await AgendaAPI.deleteEventType(eventType.id);
    await load();
  } catch (error) {
    useAlert(error.response?.data?.message || t('AGENDA.ERROR'));
  }
};

onMounted(() => {
  personId.value = currentUser.value.id;
  if (!agents.value.length) store.dispatch('agents/get');
  load();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div class="flex flex-col w-full max-w-4xl gap-8 px-6 py-8 mx-auto">
      <header class="flex items-center gap-3">
        <router-link
          :to="{ name: 'agenda_index' }"
          class="i-lucide-arrow-left size-5 text-n-slate-11"
          :aria-label="$t('AGENDA.HEADER')"
        />
        <div class="flex flex-col gap-1">
          <h1 class="text-heading-2 text-n-slate-12">
            {{ $t('AGENDA.SETTINGS.HEADER') }}
          </h1>
          <p class="text-body-main text-n-slate-11">
            {{ $t('AGENDA.SETTINGS.DESCRIPTION') }}
          </p>
        </div>
      </header>

      <section class="flex flex-col gap-3">
        <div class="flex items-center justify-between gap-3">
          <h2 class="text-base font-medium text-n-slate-12">
            {{ $t('AGENDA.SETTINGS.TYPES') }}
          </h2>
          <Button
            v-if="isAdmin"
            sm
            icon="i-lucide-plus"
            :label="$t('AGENDA.SETTINGS.TYPE.NEW')"
            @click="typeDialogRef.open()"
          />
        </div>
        <p v-if="!eventTypes.length" class="text-sm text-n-slate-11">
          {{ $t('AGENDA.SETTINGS.NO_TYPES') }}
        </p>
        <ul
          v-else
          class="flex flex-col m-0 list-none divide-y rounded-xl divide-n-weak bg-n-card outline outline-1 outline-n-container"
        >
          <li
            v-for="eventType in eventTypes"
            :key="eventType.id"
            class="flex flex-wrap items-center gap-3 px-4 py-3"
          >
            <span class="flex flex-col flex-1 min-w-48">
              <span
                class="text-sm font-medium"
                :class="eventType.active ? 'text-n-slate-12' : 'text-n-slate-10'"
              >
                {{ eventType.name }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{
                  $t('AGENDA.SETTINGS.TYPE.SUMMARY', {
                    minutes: eventType.duration_minutes,
                    owner:
                      ownerName(eventType.default_owner_id) ||
                      $t('AGENDA.SETTINGS.TYPE.NO_DEFAULT_OWNER'),
                  })
                }}
                <template v-if="eventType.requires_confirmation">
                  · {{ $t('AGENDA.SETTINGS.TYPE.REQUIRES_CONFIRMATION') }}
                </template>
                <template v-if="!eventType.active">
                  · {{ $t('AGENDA.SETTINGS.TYPE.INACTIVE') }}
                </template>
              </span>
            </span>
            <template v-if="isAdmin">
              <Button
                xs
                ghost
                slate
                icon="i-lucide-pencil"
                :title="$t('AGENDA.SETTINGS.TYPE.EDIT')"
                @click="typeDialogRef.open(eventType)"
              />
              <Button
                xs
                ghost
                ruby
                icon="i-lucide-trash-2"
                :title="$t('AGENDA.DIALOG.DELETE')"
                @click="remove(eventType)"
              />
            </template>
          </li>
        </ul>
      </section>

      <section class="flex flex-col gap-3">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex flex-col gap-1">
            <h2 class="text-base font-medium text-n-slate-12">
              {{ $t('AGENDA.SETTINGS.HOURS.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ $t('AGENDA.SETTINGS.HOURS.DESCRIPTION') }}
            </p>
          </div>
          <Select
            v-if="personOptions.length > 1"
            v-model="personId"
            :options="personOptions"
          />
        </div>
        <div
          v-if="personId"
          class="p-4 rounded-xl bg-n-card outline outline-1 outline-n-container"
        >
          <WorkingHours
            :user-id="personId"
            :availability="personAvailability"
            @saved="load"
          />
        </div>
      </section>
    </div>

    <EventTypeDialog ref="typeDialogRef" @saved="load" />
  </section>
</template>
