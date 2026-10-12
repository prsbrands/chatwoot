<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useLocale } from 'shared/composables/useLocale';
import AiEvolutionAPI from 'dashboard/api/aiEvolution';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Uma proposta: o que muda (trecho novo, correção ou regra), onde, o texto
// (editável antes de aplicar), o porquê e as conversas que ensinaram — a frase
// do cliente e o que a equipe respondeu. Aplicar, recusar com motivo e, nas
// aplicadas, desfazer.
const props = defineProps({
  suggestion: { type: Object, required: true },
});
const emit = defineEmits(['changed']);

const KIND_ICONS = {
  knowledge_add: 'i-lucide-book-plus',
  knowledge_update: 'i-lucide-book-check',
  prompt_rule: 'i-lucide-list-checks',
};

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { resolvedLocale } = useLocale();

const title = ref(props.suggestion.title);
const content = ref(props.suggestion.content);
const isRejecting = ref(false);
const reason = ref('');
const isBusy = ref(false);

const pending = computed(() => props.suggestion.status === 'pending');
const where = computed(() => {
  const s = props.suggestion;
  if (s.kind === 'prompt_rule')
    return t('AI_EVOLUTION.WHERE.PROMPT', { persona: s.persona_name });
  return s.target_doc_title
    ? t('AI_EVOLUTION.WHERE.DOC', { doc: s.target_doc_title })
    : t('AI_EVOLUTION.WHERE.LEARNED_DOC');
});
const decidedAt = computed(() => {
  const at = props.suggestion.applied_at || props.suggestion.rejected_at;
  if (!at) return '';
  return new Intl.DateTimeFormat(resolvedLocale.value, {
    dateStyle: 'medium',
  }).format(new Date(at * 1000));
});

const run = async (action, payload = {}) => {
  isBusy.value = true;
  try {
    await AiEvolutionAPI.action(props.suggestion.id, action, payload);
    useAlert(t(`AI_EVOLUTION.DONE.${action}`));
    emit('changed');
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        t('AI_EVOLUTION.API.ERROR')
    );
  } finally {
    isBusy.value = false;
  }
};

const apply = () =>
  run('apply', {
    title: title.value !== props.suggestion.title ? title.value : undefined,
    content:
      content.value !== props.suggestion.content ? content.value : undefined,
  });
const reject = () => run('reject', { reason: reason.value.trim() });
</script>

<template>
  <article
    class="flex flex-col gap-3 p-4 rounded-xl bg-n-card outline outline-1 outline-n-container"
  >
    <header class="flex flex-wrap items-center gap-2 text-xs text-n-slate-11">
      <span class="size-4" :class="KIND_ICONS[suggestion.kind]" />
      <span class="font-medium text-n-slate-12">
        {{ $t(`AI_EVOLUTION.KIND.${suggestion.kind}`) }}
      </span>
      <span>· {{ where }}</span>
      <span class="px-1.5 rounded-md bg-n-teal-3 text-n-teal-11">
        {{
          $t(
            'AI_EVOLUTION.EVIDENCE_COUNT',
            { count: suggestion.evidence_count },
            suggestion.evidence_count
          )
        }}
      </span>
      <span v-if="suggestion.edited">· {{ $t('AI_EVOLUTION.EDITED') }}</span>
      <span v-if="decidedAt" class="ms-auto">
        {{
          suggestion.status === 'applied'
            ? $t('AI_EVOLUTION.APPLIED_BY', {
                name: suggestion.applied_by,
                date: decidedAt,
              })
            : $t('AI_EVOLUTION.REJECTED_BY', {
                name: suggestion.rejected_by,
                date: decidedAt,
              })
        }}
      </span>
    </header>

    <template v-if="pending">
      <Input
        v-if="suggestion.kind !== 'prompt_rule'"
        v-model="title"
        :label="$t('AI_EVOLUTION.TITLE')"
      />
      <div
        v-if="suggestion.kind === 'knowledge_update'"
        class="flex flex-col gap-1"
      >
        <span class="text-label-small text-n-slate-11">{{
          $t('AI_EVOLUTION.REPLACES')
        }}</span>
        <p
          class="px-3 py-2 m-0 text-sm line-through whitespace-pre-wrap rounded-lg bg-n-ruby-2 text-n-slate-11"
        >
          {{ suggestion.replace_text }}
        </p>
      </div>
      <TextArea
        v-model="content"
        :label="
          suggestion.kind === 'prompt_rule'
            ? $t('AI_EVOLUTION.RULE')
            : $t('AI_EVOLUTION.TEXT')
        "
        :max-length="2000"
      />
    </template>
    <template v-else>
      <h3 class="m-0 text-sm font-medium text-n-slate-12">
        {{ suggestion.title }}
      </h3>
      <p class="m-0 text-sm whitespace-pre-wrap text-n-slate-12">
        {{ suggestion.content }}
      </p>
      <p v-if="suggestion.reject_reason" class="m-0 text-xs text-n-slate-11">
        {{ $t('AI_EVOLUTION.REASON', { reason: suggestion.reject_reason }) }}
      </p>
    </template>

    <p v-if="suggestion.rationale" class="m-0 text-xs text-n-slate-11">
      <span class="font-medium">{{ $t('AI_EVOLUTION.WHY') }}</span>
      {{ suggestion.rationale }}
    </p>

    <ul class="flex flex-col gap-2 m-0 list-none">
      <li
        v-for="(item, k) in suggestion.evidence"
        :key="k"
        class="flex flex-col gap-1 px-3 py-2 text-xs rounded-lg bg-n-alpha-1"
      >
        <span v-if="item.customer_quote" class="text-n-slate-12">
          <span class="font-medium">{{ $t('AI_EVOLUTION.CUSTOMER') }}</span>
          {{ $t('AI_EVOLUTION.QUOTE', { text: item.customer_quote }) }}
        </span>
        <span v-if="item.team_quote" class="text-n-slate-12">
          <span class="font-medium">{{ $t('AI_EVOLUTION.TEAM') }}</span>
          {{ $t('AI_EVOLUTION.QUOTE', { text: item.team_quote }) }}
        </span>
        <router-link
          :to="
            accountScopedRoute('inbox_conversation', {
              conversation_id: item.conversation_id,
            })
          "
          class="text-n-slate-11 hover:underline w-fit"
        >
          {{
            $t('AI_EVOLUTION.OPEN_CONVERSATION', { id: item.conversation_id })
          }}
        </router-link>
      </li>
    </ul>

    <div v-if="pending && isRejecting" class="flex flex-col gap-2">
      <Input v-model="reason" :placeholder="$t('AI_EVOLUTION.REJECT_REASON')" />
      <div class="flex gap-2">
        <Button
          sm
          ruby
          :label="$t('AI_EVOLUTION.ACTIONS.reject')"
          :disabled="isBusy"
          @click="reject"
        />
        <Button
          sm
          slate
          faded
          :label="$t('AI_EVOLUTION.CANCEL')"
          @click="isRejecting = false"
        />
      </div>
    </div>
    <div v-else class="flex flex-wrap gap-2">
      <template v-if="pending">
        <Button
          sm
          icon="i-lucide-check"
          :label="$t('AI_EVOLUTION.ACTIONS.apply')"
          :disabled="isBusy || !content.trim() || !title.trim()"
          @click="apply"
        />
        <Button
          sm
          slate
          faded
          :label="$t('AI_EVOLUTION.ACTIONS.reject')"
          :disabled="isBusy"
          @click="isRejecting = true"
        />
      </template>
      <Button
        v-else-if="suggestion.status === 'applied'"
        sm
        slate
        faded
        icon="i-lucide-undo-2"
        :label="$t('AI_EVOLUTION.ACTIONS.undo')"
        :disabled="isBusy"
        @click="run('undo')"
      />
    </div>
  </article>
</template>
