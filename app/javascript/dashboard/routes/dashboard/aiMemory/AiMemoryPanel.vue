<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useLocale } from 'shared/composables/useLocale';
import AiMemoryAPI from 'dashboard/api/aiMemory';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Memoria da IA do contato (no painel da conversa e na pagina do contato): o
// resumo e os fatos que a IA le antes de responder, em qualquer canal. Fato
// escrito ou corrigido aqui vira da equipe e a IA nao mexe mais; fixado vai
// primeiro no prompt e tambem fica como esta.
const props = defineProps({
  contactId: { type: Number, default: null },
});

const SUMMARY_MAX = 1500;

const { t } = useI18n();
const { resolvedLocale } = useLocale();

const memory = ref(null);
const editingSummary = ref(false);
const summaryDraft = ref('');
const newFact = ref('');
const editingFactId = ref(null);
const factDraft = ref('');
const isSaving = ref(false);

const alertError = error =>
  useAlert(
    error.response?.data?.message ||
      error.response?.data?.error ||
      t('AI_MEMORY.API.ERROR')
  );

const load = async () => {
  if (!props.contactId) return;
  try {
    const { data } = await AiMemoryAPI.show(props.contactId);
    memory.value = data;
  } catch (error) {
    alertError(error);
  }
};

watch(() => props.contactId, load, { immediate: true });

const isEmpty = computed(
  () => memory.value && !memory.value.summary && !memory.value.facts.length
);
const refreshedLabel = computed(() => {
  if (!memory.value?.refreshed_at) return '';
  return t('AI_MEMORY.REFRESHED_AT', {
    date: new Intl.DateTimeFormat(resolvedLocale.value, {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(memory.value.refreshed_at)),
  });
});

const save = async action => {
  isSaving.value = true;
  try {
    await action();
    await load();
    return true;
  } catch (error) {
    alertError(error);
    return false;
  } finally {
    isSaving.value = false;
  }
};

const editSummary = () => {
  summaryDraft.value = memory.value.summary;
  editingSummary.value = true;
};
const saveSummary = async () => {
  const saved = await save(() =>
    AiMemoryAPI.updateSummary(props.contactId, summaryDraft.value.trim())
  );
  if (saved) editingSummary.value = false;
};

const addFact = async () => {
  if (!newFact.value.trim()) return;
  const saved = await save(() =>
    AiMemoryAPI.createFact(props.contactId, newFact.value.trim())
  );
  if (saved) newFact.value = '';
};

const editFact = fact => {
  editingFactId.value = fact.id;
  factDraft.value = fact.body;
};
const saveFact = async () => {
  if (!factDraft.value.trim()) return;
  const saved = await save(() =>
    AiMemoryAPI.updateFact(editingFactId.value, {
      body: factDraft.value.trim(),
    })
  );
  if (saved) editingFactId.value = null;
};

const togglePin = fact =>
  save(() => AiMemoryAPI.updateFact(fact.id, { pinned: !fact.pinned }));
const removeFact = fact => save(() => AiMemoryAPI.deleteFact(fact.id));
</script>

<template>
  <div v-if="memory" class="flex flex-col gap-3 px-4 py-3">
    <p v-if="isEmpty" class="text-sm text-n-slate-11">
      {{ $t('AI_MEMORY.EMPTY') }}
    </p>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-2">
        <span class="text-label-small text-n-slate-11">
          {{ $t('AI_MEMORY.SUMMARY') }}
        </span>
        <Button
          v-if="!editingSummary"
          xs
          ghost
          slate
          icon="i-lucide-pencil"
          :title="$t('AI_MEMORY.EDIT_SUMMARY')"
          @click="editSummary"
        />
      </div>
      <template v-if="editingSummary">
        <TextArea
          v-model="summaryDraft"
          :max-length="SUMMARY_MAX"
          auto-height
          min-height="6rem"
        />
        <div class="flex justify-end gap-2">
          <Button
            xs
            ghost
            slate
            :label="$t('AI_MEMORY.CANCEL')"
            @click="editingSummary = false"
          />
          <Button
            xs
            :label="$t('AI_MEMORY.SAVE')"
            :is-loading="isSaving"
            @click="saveSummary"
          />
        </div>
      </template>
      <p
        v-else-if="memory.summary"
        class="text-sm whitespace-pre-line break-words text-n-slate-12"
      >
        {{ memory.summary }}
      </p>
      <p v-else class="text-sm text-n-slate-10">
        {{ $t('AI_MEMORY.NO_SUMMARY') }}
      </p>
      <span v-if="refreshedLabel" class="text-xs text-n-slate-10">
        {{ refreshedLabel }}
      </span>
    </div>

    <div class="flex flex-col gap-2">
      <span class="text-label-small text-n-slate-11">
        {{ $t('AI_MEMORY.FACTS') }}
      </span>
      <div
        v-for="fact in memory.facts"
        :key="fact.id"
        class="flex items-start gap-2 group"
      >
        <button
          type="button"
          class="mt-0.5 shrink-0 size-4 i-lucide-pin"
          :class="
            fact.pinned
              ? 'text-n-amber-11'
              : 'text-n-slate-9 opacity-30 group-hover:opacity-100'
          "
          :title="fact.pinned ? $t('AI_MEMORY.UNPIN') : $t('AI_MEMORY.PIN')"
          @click="togglePin(fact)"
        />
        <div
          v-if="editingFactId === fact.id"
          class="flex flex-col flex-1 gap-2"
        >
          <Input v-model="factDraft" size="sm" @enter="saveFact" />
          <div class="flex justify-end gap-2">
            <Button
              xs
              ghost
              slate
              :label="$t('AI_MEMORY.CANCEL')"
              @click="editingFactId = null"
            />
            <Button
              xs
              :label="$t('AI_MEMORY.SAVE')"
              :is-loading="isSaving"
              @click="saveFact"
            />
          </div>
        </div>
        <template v-else>
          <span class="flex-1 min-w-0 text-sm break-words text-n-slate-12">
            {{ fact.body }}
            <span
              v-if="fact.source === 'manual'"
              class="px-1.5 ms-1 text-xs rounded bg-n-alpha-2 text-n-slate-11"
            >
              {{ $t('AI_MEMORY.BY_TEAM') }}
            </span>
          </span>
          <div
            class="flex gap-1 opacity-0 group-hover:opacity-100 focus-within:opacity-100"
          >
            <Button
              xs
              ghost
              slate
              icon="i-lucide-pencil"
              :title="$t('AI_MEMORY.EDIT_FACT')"
              @click="editFact(fact)"
            />
            <Button
              xs
              ghost
              ruby
              icon="i-lucide-trash-2"
              :title="$t('AI_MEMORY.DELETE_FACT')"
              @click="removeFact(fact)"
            />
          </div>
        </template>
      </div>
      <div class="flex gap-2">
        <Input
          v-model="newFact"
          class="flex-1"
          size="sm"
          :placeholder="$t('AI_MEMORY.NEW_FACT')"
          @enter="addFact"
        />
        <Button
          sm
          ghost
          slate
          icon="i-lucide-plus"
          :title="$t('AI_MEMORY.ADD_FACT')"
          :disabled="!newFact.trim()"
          @click="addFact"
        />
      </div>
    </div>
  </div>
</template>
