<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { INTERVAL_FLOOR, MAX_VARIANTS, WEEKDAYS } from '../constants';

// A mensagem (até 3 variações, o rodapé de saída, lista fria) e o ritmo de
// envio. Salvar uma campanha pronta a devolve a rascunho: a lista tem de ser
// preparada de novo.
const props = defineProps({
  campaign: { type: Object, required: true },
});
const emit = defineEmits(['updated']);

const VARIABLES = ['{name}', '{full_name}', '{company}'];
const OPTION_EXAMPLE = '{Hi|Hello}';

const { t } = useI18n();

const name = ref(props.campaign.name);
const variants = ref([...props.campaign.variants]);
const cold = ref(props.campaign.cold);
const footer = ref(props.campaign.opt_out_footer || '');
const pacing = reactive({ ...props.campaign.pacing });
const isSaving = ref(false);

const noDays = computed(() => !pacing.days.length);
const intervalInvalid = computed(
  () =>
    pacing.interval_min < INTERVAL_FLOOR ||
    pacing.interval_min > pacing.interval_max
);
const canSave = computed(
  () =>
    name.value.trim() &&
    variants.value.some(text => text.trim()) &&
    !noDays.value &&
    !intervalInvalid.value
);

const toggleDay = day => {
  pacing.days = pacing.days.includes(day)
    ? pacing.days.filter(item => item !== day)
    : [...pacing.days, day].sort();
};

const save = async () => {
  if (isSaving.value) return;
  isSaving.value = true;
  try {
    const { data } = await OutreachAPI.update(props.campaign.id, {
      name: name.value.trim(),
      variants: variants.value.map(text => text.trim()).filter(Boolean),
      cold: cold.value,
      opt_out_footer: footer.value.trim(),
      pacing: {
        ...pacing,
        max_per_day: pacing.max_per_day === '' ? null : pacing.max_per_day,
      },
    });
    useAlert(t('OUTREACH.SAVED'));
    emit('updated', data);
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('OUTREACH.API.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <section class="flex flex-col gap-4 p-4 rounded-xl bg-n-card">
    <h2 class="text-heading-3 text-n-slate-12">
      {{ $t('OUTREACH.MESSAGE.TITLE') }}
    </h2>
    <Input v-model="name" :label="$t('OUTREACH.FIELDS.NAME')" />

    <div class="flex flex-col gap-3">
      <div
        v-for="(_text, index) in variants"
        :key="index"
        class="flex flex-col gap-1"
      >
        <span class="flex items-center justify-between text-sm text-n-slate-12">
          {{ $t('OUTREACH.MESSAGE.VARIANT', { number: index + 1 }) }}
          <Button
            v-if="variants.length > 1"
            ghost
            slate
            xs
            icon="i-lucide-trash-2"
            :label="$t('OUTREACH.MESSAGE.REMOVE_VARIANT')"
            @click="variants.splice(index, 1)"
          />
        </span>
        <TextArea v-model="variants[index]" :rows="4" />
      </div>
      <Button
        v-if="variants.length < MAX_VARIANTS"
        slate
        faded
        sm
        icon="i-lucide-plus"
        :label="$t('OUTREACH.MESSAGE.ADD_VARIANT')"
        @click="variants.push('')"
      />
      <p class="text-xs text-n-slate-11">
        {{ $t('OUTREACH.MESSAGE.HINT_VARIABLES') }}
        <code v-for="variable in VARIABLES" :key="variable" class="mx-0.5">
          {{ variable }}
        </code>
        {{ $t('OUTREACH.MESSAGE.HINT_OPTIONS') }}
        <code>{{ OPTION_EXAMPLE }}</code>
        {{ $t('OUTREACH.MESSAGE.HINT_BUBBLES') }}
      </p>
    </div>

    <label class="flex items-start gap-2 text-sm text-n-slate-12">
      <input v-model="cold" type="checkbox" class="mt-1" />
      <span class="flex flex-col">
        {{ $t('OUTREACH.MESSAGE.COLD') }}
        <span class="text-xs text-n-slate-11">
          {{ $t('OUTREACH.MESSAGE.COLD_HINT') }}
        </span>
      </span>
    </label>
    <label class="flex flex-col gap-1">
      <span class="text-sm text-n-slate-12">
        {{ $t('OUTREACH.MESSAGE.FOOTER') }}
      </span>
      <TextArea v-model="footer" :rows="2" />
      <span class="text-xs text-n-slate-11">
        {{ $t('OUTREACH.MESSAGE.FOOTER_HINT') }}
      </span>
    </label>

    <h2 class="pt-2 text-heading-3 text-n-slate-12">
      {{ $t('OUTREACH.PACING.TITLE') }}
    </h2>
    <p class="text-xs text-n-slate-11">{{ $t('OUTREACH.PACING.HINT') }}</p>
    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <Input
        v-model="pacing.window_start"
        type="number"
        :label="$t('OUTREACH.PACING.WINDOW_START')"
      />
      <Input
        v-model="pacing.window_end"
        type="number"
        :label="$t('OUTREACH.PACING.WINDOW_END')"
      />
      <Input
        v-model="pacing.interval_min"
        type="number"
        :label="$t('OUTREACH.PACING.INTERVAL_MIN')"
        :message-type="intervalInvalid ? 'error' : 'info'"
        :message="
          intervalInvalid
            ? $t('OUTREACH.PACING.INTERVAL_FLOOR', { seconds: INTERVAL_FLOOR })
            : ''
        "
      />
      <Input
        v-model="pacing.interval_max"
        type="number"
        :label="$t('OUTREACH.PACING.INTERVAL_MAX')"
      />
      <Input
        v-model="pacing.max_per_hour"
        type="number"
        :label="$t('OUTREACH.PACING.MAX_PER_HOUR')"
      />
      <Input
        v-model="pacing.max_per_day"
        type="number"
        :label="$t('OUTREACH.PACING.MAX_PER_DAY')"
      />
      <Input
        v-model="pacing.batch_size"
        type="number"
        :label="$t('OUTREACH.PACING.BATCH_SIZE')"
      />
      <div class="grid grid-cols-2 gap-2">
        <Input
          v-model="pacing.batch_pause_min"
          type="number"
          :label="$t('OUTREACH.PACING.PAUSE_MIN')"
        />
        <Input
          v-model="pacing.batch_pause_max"
          type="number"
          :label="$t('OUTREACH.PACING.PAUSE_MAX')"
        />
      </div>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-sm text-n-slate-12">
        {{ $t('OUTREACH.PACING.DAYS') }}
      </span>
      <Button
        v-for="day in WEEKDAYS"
        :key="day"
        xs
        :slate="!pacing.days.includes(day)"
        :faded="!pacing.days.includes(day)"
        :label="$t(`OUTREACH.WEEKDAY.${day}`)"
        @click="toggleDay(day)"
      />
    </div>

    <div>
      <Button
        :label="$t('OUTREACH.SAVE')"
        :is-loading="isSaving"
        :disabled="!canSave || isSaving"
        @click="save"
      />
    </div>
  </section>
</template>
