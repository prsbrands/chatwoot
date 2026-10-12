<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import CasesAPI from 'dashboard/api/cases';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TypeDialog from '../components/TypeDialog.vue';

// Configuração dos casos (admin): o prefixo do número e os tipos. A conta
// nasce com um modelo neutro; cada negócio renomeia, ajusta prazos e
// acrescenta os campos que precisa. Tipo com caso não se apaga: desativa.
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const types = ref([]);
const prefix = ref('');
const savedPrefix = ref('');
const isLoading = ref(true);
const dialogRef = ref(null);

const fail = error =>
  useAlert(
    error.response?.data?.error ||
      error.response?.data?.message ||
      t('CASES.API.ERROR')
  );

const fetchTypes = async () => {
  const { data } = await CasesAPI.types();
  types.value = data.payload;
};

const savePrefix = async () => {
  try {
    const { data } = await CasesAPI.updateSettings({ prefix: prefix.value });
    prefix.value = data.prefix;
    savedPrefix.value = data.prefix;
    useAlert(t('CASES.SETTINGS.PREFIX_SAVED'));
  } catch (error) {
    fail(error);
  }
};

const move = async (index, direction) => {
  const list = [...types.value];
  const [type] = list.splice(index, 1);
  list.splice(index + direction, 0, type);
  types.value = list;
  try {
    await Promise.all(
      list.map((entry, position) =>
        entry.position === position
          ? null
          : CasesAPI.updateType(entry.id, { position })
      )
    );
    await fetchTypes();
  } catch (error) {
    fail(error);
  }
};

const remove = async type => {
  try {
    await CasesAPI.deleteType(type.id);
    await fetchTypes();
  } catch (error) {
    useAlert(t('CASES.SETTINGS.TYPE_IN_USE'));
  }
};

onMounted(async () => {
  try {
    const [, { data }] = await Promise.all([fetchTypes(), CasesAPI.settings()]);
    prefix.value = data.prefix;
    savedPrefix.value = data.prefix;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <router-link
        :to="accountScopedRoute('cases_index')"
        class="flex items-center gap-1 text-xs text-n-slate-11 hover:underline w-fit"
      >
        <span class="i-lucide-arrow-left size-3" />
        {{ $t('CASES.BACK') }}
      </router-link>
      <h1 class="text-heading-2 text-n-slate-12">
        {{ $t('CASES.SETTINGS.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ $t('CASES.SETTINGS.DESCRIPTION') }}
      </p>
    </header>

    <div v-if="isLoading" class="flex px-6 py-5"><Spinner /></div>

    <div v-else class="flex flex-col max-w-3xl gap-8 px-6 py-5">
      <section class="flex flex-col gap-2">
        <h2 class="text-sm font-medium text-n-slate-12">
          {{ $t('CASES.SETTINGS.PREFIX') }}
        </h2>
        <p class="m-0 text-xs text-n-slate-11">
          {{
            $t('CASES.SETTINGS.PREFIX_HINT', {
              example: `${prefix || 'CAS'}-${new Date().getFullYear()}-0001`,
            })
          }}
        </p>
        <div class="flex items-center gap-2">
          <div class="w-32">
            <Input v-model="prefix" />
          </div>
          <Button
            sm
            :label="$t('CASES.SAVE')"
            :disabled="!prefix.trim() || prefix === savedPrefix"
            @click="savePrefix"
          />
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-medium text-n-slate-12">
            {{ $t('CASES.SETTINGS.TYPES') }}
          </h2>
          <Button
            sm
            icon="i-lucide-plus"
            :label="$t('CASES.SETTINGS.NEW_TYPE')"
            @click="dialogRef.open()"
          />
        </div>
        <ul
          class="flex flex-col m-0 list-none divide-y rounded-xl divide-n-weak bg-n-card outline outline-1 outline-n-container"
        >
          <li
            v-for="(type, index) in types"
            :key="type.id"
            class="flex items-center gap-3 px-4 py-3"
            :class="{ 'opacity-60': !type.active }"
          >
            <span
              class="rounded-full size-3 shrink-0"
              :style="{ backgroundColor: type.color }"
            />
            <div class="flex flex-col flex-1 min-w-0">
              <span class="text-sm text-n-slate-12">
                {{ type.name }}
                <span v-if="!type.active" class="text-xs text-n-slate-11">
                  · {{ $t('CASES.SETTINGS.INACTIVE') }}
                </span>
              </span>
              <span class="text-xs text-n-slate-11">
                {{
                  type.sla_hours
                    ? $t('CASES.SETTINGS.SLA_SUMMARY', {
                        hours: type.sla_hours,
                      })
                    : $t('CASES.SETTINGS.NO_SLA')
                }}
                · {{ $t(`CASES.PRIORITY.${type.default_priority}`) }} ·
                {{
                  $t(
                    'CASES.SETTINGS.FIELD_COUNT',
                    { count: type.fields.length },
                    type.fields.length
                  )
                }}
              </span>
            </div>
            <Button
              xs
              ghost
              slate
              icon="i-lucide-arrow-up"
              :disabled="index === 0"
              @click="move(index, -1)"
            />
            <Button
              xs
              ghost
              slate
              icon="i-lucide-arrow-down"
              :disabled="index === types.length - 1"
              @click="move(index, 1)"
            />
            <Button
              xs
              ghost
              slate
              icon="i-lucide-pencil"
              :title="$t('CASES.SETTINGS.EDIT_TYPE')"
              @click="dialogRef.open(type)"
            />
            <Button
              xs
              ghost
              ruby
              icon="i-lucide-trash-2"
              :title="$t('CASES.SETTINGS.DELETE_TYPE')"
              @click="remove(type)"
            />
          </li>
        </ul>
      </section>
    </div>

    <TypeDialog ref="dialogRef" @saved="fetchTypes" />
  </section>
</template>
