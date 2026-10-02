<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import SalesPipelineAPI from 'dashboard/api/salesPipeline';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TaskDialog from '../components/TaskDialog.vue';
import TaskRow from '../components/TaskRow.vue';

// O que ficou combinado, com prazo — e o que já venceu sem ninguém fazer. As
// pendentes vêm do backend já por prazo; aqui só se separam em grupos.
const STATUSES = ['pending', 'done'];
const OWNERS = ['me', 'all'];

const tasks = ref([]);
const status = ref('pending');
const owner = ref('me');
const isLoading = ref(true);
const dialogRef = ref(null);

const fetchTasks = async () => {
  isLoading.value = true;
  try {
    const { data } = await SalesPipelineAPI.tasks({
      status: status.value,
      assignee_id: owner.value === 'me' ? 'me' : undefined,
    });
    tasks.value = data.payload;
  } finally {
    isLoading.value = false;
  }
};

const endOfToday = () => {
  const date = new Date();
  date.setHours(23, 59, 59, 999);
  return date.getTime();
};

const groups = computed(() => {
  if (status.value === 'done') return [{ id: 'DONE', tasks: tasks.value }];
  const now = Date.now();
  const today = endOfToday();
  const due = task => (task.due_at ? task.due_at * 1000 : null);
  return [
    { id: 'OVERDUE', tasks: tasks.value.filter(task => due(task) && due(task) < now) },
    {
      id: 'TODAY',
      tasks: tasks.value.filter(task => due(task) >= now && due(task) <= today),
    },
    { id: 'UPCOMING', tasks: tasks.value.filter(task => due(task) > today) },
    { id: 'NO_DATE', tasks: tasks.value.filter(task => !task.due_at) },
  ].filter(group => group.tasks.length);
});

const newTask = () => dialogRef.value.open();
const editTask = task => dialogRef.value.open({ task });

watch([status, owner], fetchTasks);
onMounted(fetchTasks);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col gap-1 min-w-0">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('SALES_PIPELINE.TASKS.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('SALES_PIPELINE.TASKS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        sm
        icon="i-lucide-plus"
        :label="$t('SALES_PIPELINE.TASKS.NEW')"
        @click="newTask"
      />
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pt-4">
      <Button
        v-for="option in STATUSES"
        :key="option"
        xs
        :slate="status !== option"
        :faded="status !== option"
        :label="$t(`SALES_PIPELINE.TASKS.STATUS.${option}`)"
        @click="status = option"
      />
      <span class="w-px h-4 mx-1 bg-n-weak" />
      <Button
        v-for="option in OWNERS"
        :key="option"
        xs
        :slate="owner !== option"
        :faded="owner !== option"
        :label="$t(`SALES_PIPELINE.TASKS.OWNER.${option}`)"
        @click="owner = option"
      />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
    </div>

    <p v-else-if="!tasks.length" class="px-6 py-5 text-sm text-n-slate-11">
      {{ $t(`SALES_PIPELINE.TASKS.EMPTY.${status}`) }}
    </p>

    <div v-else class="flex flex-col gap-6 px-6 py-5">
      <section
        v-for="group in groups"
        :key="group.id"
        class="flex flex-col gap-2"
      >
        <h2
          class="text-xs font-medium tracking-wide uppercase"
          :class="group.id === 'OVERDUE' ? 'text-n-ruby-11' : 'text-n-slate-11'"
        >
          {{ $t(`SALES_PIPELINE.TASKS.GROUP.${group.id}`) }} ·
          {{ group.tasks.length }}
        </h2>
        <ul
          class="flex flex-col divide-y rounded-xl divide-n-weak bg-n-card outline outline-1 outline-n-container"
        >
          <li v-for="task in group.tasks" :key="task.id" class="px-4 py-3">
            <TaskRow :task="task" @changed="fetchTasks" @edit="editTask" />
          </li>
        </ul>
      </section>
    </div>

    <TaskDialog ref="dialogRef" @saved="fetchTasks" />
  </section>
</template>
