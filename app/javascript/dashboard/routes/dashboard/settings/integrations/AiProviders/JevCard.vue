<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const { t } = useI18n();

// A ordem e os grupos são o que a tela mostra; os ids são os mesmos que o
// JevController aceita e que o workflow do n8n lê.
const GROUPS = [
  { id: 'SAVE', activities: ['knowledge', 'model_routing', 'no_reply'] },
  {
    id: 'HANDOFF',
    activities: ['human_request', 'mood', 'opt_out', 'manipulation'],
  },
  { id: 'REVIEW', activities: ['reply_review'] },
  { id: 'FOLLOWUP', activities: ['followup'] },
  { id: 'SALES', activities: ['deal_stage'] },
];

const card = ref(null);
const isLoading = ref(true);
const isSaving = ref(false);
const apiKey = ref('');
const showKeyInput = ref(false);
const reviewRules = ref('');
const consentDialogRef = ref(null);
const decideDialogRef = ref(null);
const pendingActivity = ref(null);

const alertError = error =>
  useAlert(
    error.response?.data?.error || t('INTEGRATION_SETTINGS.BOTLAYER.API.ERROR')
  );

const apply = data => {
  card.value = data;
  reviewRules.value = (data.review_rules || []).join('\n');
  showKeyInput.value = !data.has_key;
};

const run = async request => {
  isSaving.value = true;
  try {
    const { data } = await request();
    apply(data);
    return true;
  } catch (error) {
    alertError(error);
    return false;
  } finally {
    isSaving.value = false;
  }
};

const summary = computed(() => card.value?.summary || {});
const week = computed(() => summary.value.week || {});

const deciding = computed(() =>
  Object.values(card.value?.activities || {}).filter(s => s === 'deciding')
);

const status = computed(() => {
  if (!card.value?.enabled) return 'OFF';
  return deciding.value.length ? 'DECIDING' : 'OBSERVING';
});

// Erro mais novo que o último acerto: o Jev está parado agora, não "falhou
// uma vez na semana".
const failing = computed(() => {
  const { last_error: lastError, last_ok_at: lastOk } = summary.value;
  if (!card.value?.enabled || !lastError) return null;
  if (lastOk && new Date(lastOk) > new Date(lastError.created_at)) return null;
  return lastError.error;
});

// Custo por semana cabe em milésimos de centavo; arredondar para centavos
// mostraria sempre zero.
const cost = computed(() => {
  const value = Number(week.value.cost_usd || 0);
  return `US$ ${value.toFixed(value < 0.01 ? 6 : 2)}`;
});

const activityStats = id => summary.value.activities?.[id];

const statsLine = id => {
  const stats = activityStats(id);
  if (!stats?.runs) return t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.NO_DATA');
  if (stats.compared) {
    return t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.AGREEMENT', {
      agreed: stats.agreed,
      compared: stats.compared,
    });
  }
  const line = t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.STATS.${id}`, {
    signals: stats.signals,
    runs: stats.runs,
    tokens: stats.tokens_saved,
  });
  if (!stats.acted) return line;
  return `${line} ${t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.ACTED', { acted: stats.acted })}`;
};

const fetchCard = async () => {
  try {
    const { data } = await BotlayerAPI.jev();
    apply(data);
  } catch (error) {
    alertError(error);
  } finally {
    isLoading.value = false;
  }
};

const saveKey = async () => {
  const saved = await run(() => BotlayerAPI.saveJevKey(apiKey.value));
  if (saved) {
    apiKey.value = '';
    useAlert(t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_SAVED'));
  }
};

const removeKey = () => run(() => BotlayerAPI.deleteJevKey());

// Cadastrar a chave não é consentir: na primeira vez que liga, quem
// administra confirma o envio das mensagens para a TypeSafe.
const turnOn = () => {
  if (card.value.consent) {
    run(() => BotlayerAPI.updateJev({ enabled: true }));
  } else {
    consentDialogRef.value.open();
  }
};

const confirmConsent = async () => {
  await run(() => BotlayerAPI.updateJev({ consent: true, enabled: true }));
  consentDialogRef.value.close();
};

const turnOff = () => run(() => BotlayerAPI.updateJev({ enabled: false }));

const setState = (id, state) =>
  run(() => BotlayerAPI.updateJev({ activities: { [id]: state } }));

const askToDecide = id => {
  pendingActivity.value = id;
  decideDialogRef.value.open();
};

const confirmDecide = async () => {
  await setState(pendingActivity.value, 'deciding');
  decideDialogRef.value.close();
};

const saveRules = async () => {
  const rules = reviewRules.value.split('\n').map(rule => rule.trim());
  const saved = await run(() =>
    BotlayerAPI.updateJev({ review_rules: rules.filter(Boolean) })
  );
  if (saved) useAlert(t('INTEGRATION_SETTINGS.BOTLAYER.API.SAVED'));
};

// Sugestões e condições por IA rodam no Rails, a pedido do atendente ou de uma
// automação: não há "observar", só ligado ou desligado.
const setTeam = team => run(() => BotlayerAPI.updateJev({ team }));

const teamLine = computed(() => {
  const runs = summary.value.activities?.captain_classifier?.runs;
  if (!runs) return t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.NO_DATA');
  return t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.STATS', { runs });
});

const stateBadgeClass = state =>
  ({
    deciding: 'bg-n-teal-3 text-n-teal-11',
    observing: 'bg-n-alpha-2 text-n-slate-11',
    off: 'bg-n-amber-3 text-n-amber-11',
  })[state];

onMounted(fetchCard);
</script>

<template>
  <div
    v-if="!isLoading && card"
    class="flex flex-col gap-4 rounded-xl bg-n-card p-5 outline outline-1 outline-n-container"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="flex flex-col gap-1">
        <p class="text-base font-medium text-n-slate-12">
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TITLE') }}
        </p>
        <p class="text-sm text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.DESCRIPTION') }}
        </p>
      </div>
      <span
        class="shrink-0 rounded-md px-2 py-0.5 text-xs font-medium"
        :class="
          status === 'OFF'
            ? 'bg-n-alpha-2 text-n-slate-11'
            : 'bg-n-teal-3 text-n-teal-11'
        "
      >
        {{ $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.STATUS.${status}`) }}
      </span>
    </div>

    <div class="flex flex-col gap-2">
      <div
        v-if="card.has_key && !showKeyInput"
        class="flex flex-wrap items-center gap-3"
      >
        <span class="text-sm text-n-teal-11">
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_OK') }}
        </span>
        <Button
          sm
          slate
          link
          :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_REPLACE')"
          @click="showKeyInput = true"
        />
        <Button
          sm
          ruby
          link
          :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_REMOVE')"
          :disabled="isSaving"
          @click="removeKey"
        />
      </div>
      <div v-else class="flex flex-wrap items-end gap-2">
        <Input
          v-model="apiKey"
          type="password"
          class="min-w-64 flex-1"
          :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_LABEL')"
          placeholder="apikey_..."
          :message="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_HELP')"
        />
        <Button
          sm
          :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.KEY_SAVE')"
          :is-loading="isSaving"
          :disabled="!apiKey"
          @click="saveKey"
        />
      </div>
    </div>

    <p
      v-if="failing"
      class="rounded-lg bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
    >
      {{
        $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.FAILING', { error: failing })
      }}
    </p>

    <template v-if="card.enabled">
      <p class="text-sm text-n-slate-12">
        {{ $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.STATUS_HELP.${status}`) }}
      </p>

      <div
        v-for="group in GROUPS"
        :key="group.id"
        class="flex flex-col rounded-lg outline outline-1 outline-n-container"
      >
        <p
          class="px-4 pt-3 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
        >
          {{ $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.GROUP.${group.id}`) }}
        </p>
        <div
          v-for="id in group.activities"
          :key="id"
          class="flex flex-col gap-2 border-b border-n-weak px-4 py-3 last:border-b-0"
        >
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.ACTIVITY.${id}.TITLE`)
              }}
            </span>
            <span
              class="rounded-md px-2 py-0.5 text-xs"
              :class="stateBadgeClass(card.activities[id])"
            >
              {{
                $t(
                  `INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.STATE.${card.activities[id]}`
                )
              }}
            </span>
          </div>
          <p class="text-sm text-n-slate-11">
            {{
              $t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.ACTIVITY.${id}.WHAT`)
            }}
          </p>
          <p
            v-if="card.activities[id] !== 'off'"
            class="text-sm text-n-slate-12"
          >
            {{ statsLine(id) }}
          </p>

          <template v-if="id === 'reply_review'">
            <TextArea
              v-model="reviewRules"
              :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.RULES_LABEL')"
              :placeholder="
                $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.RULES_PLACEHOLDER')
              "
              :max-length="2000"
              auto-height
            />
            <Button
              sm
              slate
              outline
              class="self-start"
              :label="$t('INTEGRATION_SETTINGS.BOTLAYER.SAVE')"
              :disabled="isSaving"
              @click="saveRules"
            />
          </template>

          <div class="flex flex-wrap gap-2">
            <Button
              v-if="card.activities[id] === 'observing'"
              sm
              teal
              :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.LET_DECIDE')"
              :disabled="isSaving"
              @click="askToDecide(id)"
            />
            <Button
              v-if="card.activities[id] === 'deciding'"
              sm
              slate
              outline
              :label="
                $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.BACK_TO_OBSERVE')
              "
              :disabled="isSaving"
              @click="setState(id, 'observing')"
            />
            <Button
              v-if="card.activities[id] === 'off'"
              sm
              slate
              outline
              :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.RESUME')"
              :disabled="isSaving"
              @click="setState(id, 'observing')"
            />
            <Button
              v-else
              sm
              slate
              ghost
              :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.PAUSE')"
              :disabled="isSaving"
              @click="setState(id, 'off')"
            />
          </div>
        </div>
      </div>

      <div
        class="flex flex-col gap-2 rounded-lg px-4 py-3 outline outline-1 outline-n-container"
      >
        <p
          class="text-xs font-semibold uppercase tracking-wide text-n-slate-10"
        >
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.GROUP') }}
        </p>
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.TITLE') }}
          </span>
          <span
            class="rounded-md px-2 py-0.5 text-xs"
            :class="
              card.team
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-amber-3 text-n-amber-11'
            "
          >
            {{
              card.team
                ? $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.ON')
                : $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.OFF')
            }}
          </span>
        </div>
        <p class="text-sm text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.WHAT') }}
        </p>
        <p v-if="card.team" class="text-sm text-n-slate-12">{{ teamLine }}</p>
        <Button
          sm
          :color="card.team ? 'slate' : 'blue'"
          :variant="card.team ? 'outline' : 'solid'"
          class="self-start"
          :label="
            card.team
              ? $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.TURN_OFF')
              : $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TEAM.TURN_ON')
          "
          :disabled="isSaving"
          @click="setTeam(!card.team)"
        />
      </div>

      <div class="flex flex-col gap-2">
        <p class="text-xs text-n-slate-11">
          {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.WEEK') }}
        </p>
        <div class="grid grid-cols-2 gap-4 md:grid-cols-5">
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.METRIC.CALLS') }}
            </span>
            <span class="text-lg text-n-slate-12">{{ week.calls || 0 }}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.METRIC.AVOIDED') }}
            </span>
            <span class="text-lg text-n-slate-12">
              {{ week.llm_calls_avoided || 0 }}
            </span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.METRIC.UPSET') }}
            </span>
            <span class="text-lg text-n-slate-12">{{ week.upset || 0 }}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.METRIC.COST') }}
            </span>
            <span class="text-lg text-n-slate-12">{{ cost }}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-n-slate-11">
              {{ $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.METRIC.LATENCY') }}
            </span>
            <span class="text-lg text-n-slate-12">
              {{ ((week.avg_latency_ms || 0) / 1000).toFixed(1) }} s
            </span>
          </div>
        </div>
      </div>

      <Button
        sm
        slate
        ghost
        class="self-start"
        :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TURN_OFF')"
        :disabled="isSaving"
        @click="turnOff"
      />
    </template>

    <Button
      v-else
      sm
      class="self-start"
      :label="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.TURN_ON')"
      :disabled="isSaving || !card.has_key"
      @click="turnOn"
    />

    <Dialog
      ref="consentDialogRef"
      type="alert"
      :title="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.CONSENT_TITLE')"
      :description="$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.CONSENT_TEXT')"
      :confirm-button-label="
        $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.CONSENT_CONFIRM')
      "
      :is-loading="isSaving"
      @confirm="confirmConsent"
    />

    <Dialog
      ref="decideDialogRef"
      type="alert"
      :title="
        pendingActivity
          ? $t(
              `INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.ACTIVITY.${pendingActivity}.TITLE`
            )
          : ''
      "
      :description="
        pendingActivity
          ? `${$t(`INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.ACTIVITY.${pendingActivity}.DECIDES`)} ${$t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.DECIDE_UNDO')}`
          : ''
      "
      :confirm-button-label="
        $t('INTEGRATION_SETTINGS.AI_PROVIDERS.JEV.LET_DECIDE')
      "
      :is-loading="isSaving"
      @confirm="confirmDecide"
    />
  </div>
</template>
