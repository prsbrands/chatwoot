<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import {
  CURRENCIES,
  IMAGE_TYPES,
  PAYMENT_KINDS,
  ONLINE_PROVIDERS,
  PROVIDER_ENVIRONMENTS,
} from '../constants';

// Os dados da empresa que saem nos orçamentos, faturas e recibos, a cobrança
// online (Stripe, Mercado Pago) e as formas de pagamento que a conta aceita, com as
// instruções ao cliente. A forma ligada a um provedor vira o botão "Pagar" da
// fatura.
const { t } = useI18n();

const PROFILE_FIELDS = [
  'trade_name',
  'legal_name',
  'tax_id_label',
  'tax_id',
  'phone',
  'whatsapp',
  'email',
  'website',
  'quote_prefix',
  'invoice_prefix',
  'receipt_prefix',
];

const profile = ref({});
const methods = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isUploadingLogo = ref(false);
const logoInput = ref(null);
const methodDialog = ref(null);
const method = ref({});
const isSavingMethod = ref(false);
const deleteMethodDialog = ref(null);
const methodToDelete = ref({});
const providers = ref([]);
const providerDialog = ref(null);
const providerForm = ref({});
const editingProvider = ref('stripe');
const isConnecting = ref(false);

const providerFor = key =>
  providers.value.find(provider => provider.provider === key);
const providerLabel = key => t(`COMMERCE.ONLINE.PROVIDER.${key}`);
// Conectado e ativo, mas nenhuma forma de pagamento usa: a fatura não mostra
// o botão "Pagar" deste provedor.
const providerWithoutMethod = key => {
  const provider = providerFor(key);
  return (
    provider?.active &&
    !methods.value.some(row => row.active && row.provider_id === provider.id)
  );
};
const editingConfig = computed(() => ONLINE_PROVIDERS[editingProvider.value]);
// O domínio que o Yappy valida quando a conta não informa outro.
const installationUrl = window.location.origin;
const providerFormReady = computed(() =>
  editingConfig.value.fields.every(
    field =>
      field.optional || providerForm.value.credentials?.[field.key]?.trim()
  )
);
const environmentOptions = computed(() =>
  PROVIDER_ENVIRONMENTS.map(value => ({
    value,
    label: t(`COMMERCE.ONLINE.ENVIRONMENT.${value}`),
  }))
);
const providerName = id => {
  const provider = providers.value.find(entry => entry.id === id);
  return provider ? providerLabel(provider.provider) : '';
};
const providerOptions = computed(() => [
  { value: '', label: t('COMMERCE.PAYMENT_METHODS.OFFLINE') },
  ...providers.value
    .filter(provider => provider.active)
    .map(provider => ({
      value: provider.id,
      label: providerName(provider.id),
    })),
]);

const currencyOptions = CURRENCIES.map(code => ({ value: code, label: code }));
const kindOptions = computed(() =>
  PAYMENT_KINDS.map(kind => ({
    value: kind,
    label: t(`COMMERCE.PAYMENT_KIND.${kind}`),
  }))
);

const fetchMethods = async () => {
  const { data } = await CommerceAPI.paymentMethods();
  methods.value = data.payload;
};

const fetchProviders = async () => {
  const { data } = await CommerceAPI.paymentProviders();
  providers.value = data.payload;
};

const openProvider = key => {
  editingProvider.value = key;
  providerForm.value = {
    environment: providerFor(key)?.environment || 'sandbox',
    credentials: Object.fromEntries(
      ONLINE_PROVIDERS[key].fields.map(field => [field.key, ''])
    ),
    webhook_secret: '',
  };
  providerDialog.value.open();
};

// Conectar ou trocar a chave: o servidor valida a chave no provedor (no
// Stripe, também cria o webhook da conta).
const connectProvider = async () => {
  const key = editingProvider.value;
  const current = providerFor(key);
  const payload = {
    environment: providerForm.value.environment,
    active: true,
    credentials: Object.fromEntries(
      Object.entries(providerForm.value.credentials).map(([field, value]) => [
        field,
        value.trim(),
      ])
    ),
  };
  if (ONLINE_PROVIDERS[key].webhookSecret) {
    payload.webhook_secret = providerForm.value.webhook_secret.trim();
  }
  isConnecting.value = true;
  try {
    if (current) {
      await CommerceAPI.updatePaymentProvider(current.id, payload);
    } else {
      await CommerceAPI.createPaymentProvider({ provider: key, ...payload });
    }
    providerDialog.value.close();
    await fetchProviders();
    useAlert(t('COMMERCE.ONLINE.CONNECTED', { provider: providerLabel(key) }));
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isConnecting.value = false;
  }
};

const toggleProvider = async provider => {
  try {
    await CommerceAPI.updatePaymentProvider(provider.id, {
      active: !provider.active,
    });
    await fetchProviders();
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  }
};

const saveProfile = async (extra = {}) => {
  isSaving.value = true;
  try {
    const { data } = await CommerceAPI.updateProfile({
      ...profile.value,
      ...extra,
    });
    profile.value = data;
    useAlert(t('COMMERCE.COMPANY.SAVED'));
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

// A vitrine liga e desliga na hora, sem o botão Salvar dos dados da empresa.
const toggleStorefront = enabled => saveProfile({ storefront_enabled: enabled });
const copyStorefront = async () => {
  await copyTextToClipboard(profile.value.storefront_url);
  useAlert(t('COMMERCE.STOREFRONT.COPIED'));
};

const onLogo = async event => {
  const [file] = event.target.files;
  event.target.value = '';
  if (!file) return;
  isUploadingLogo.value = true;
  try {
    const { blobId } = await uploadFile(file);
    await saveProfile({ logo_blob_id: blobId });
  } finally {
    isUploadingLogo.value = false;
  }
};

const openMethod = (existing = null) => {
  method.value = existing
    ? { ...existing }
    : {
        name: '',
        kind: 'bank_transfer',
        instructions: '',
        active: true,
        provider_id: '',
        position: methods.value.length,
      };
  method.value.provider_id = method.value.provider_id || '';
  methodDialog.value.open();
};

const saveMethod = async () => {
  if (isSavingMethod.value) return;
  isSavingMethod.value = true;
  const payload = {
    ...method.value,
    name: method.value.name.trim(),
    provider_id: method.value.provider_id || null,
  };
  try {
    if (payload.id) {
      await CommerceAPI.updatePaymentMethod(payload.id, payload);
    } else {
      await CommerceAPI.createPaymentMethod(payload);
    }
    methodDialog.value.close();
    await fetchMethods();
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isSavingMethod.value = false;
  }
};

const confirmDeleteMethod = row => {
  methodToDelete.value = row;
  deleteMethodDialog.value.open();
};

const deleteMethod = async () => {
  try {
    await CommerceAPI.deletePaymentMethod(methodToDelete.value.id);
    deleteMethodDialog.value.close();
    methodDialog.value.close();
    await fetchMethods();
  } catch (error) {
    deleteMethodDialog.value.close();
    useAlert(
      error.response?.status === 422
        ? t('COMMERCE.PAYMENT_METHODS.DELETE_IN_USE')
        : t('COMMERCE.API.ERROR')
    );
  }
};

onMounted(async () => {
  try {
    const [{ data }] = await Promise.all([
      CommerceAPI.profile(),
      fetchMethods(),
      fetchProviders(),
    ]);
    profile.value = data;
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <h1 class="text-heading-2 text-n-slate-12">
        {{ $t('COMMERCE.COMPANY.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ $t('COMMERCE.COMPANY.DESCRIPTION') }}
      </p>
    </header>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('COMMERCE.COMPANY.LOADING') }}
    </div>
    <div v-else class="flex flex-col w-full max-w-4xl gap-6 px-6 py-5">
      <section class="flex flex-col gap-4 p-4 border rounded-xl border-n-weak">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ $t('COMMERCE.COMPANY.DATA') }}
        </h2>
        <div class="flex items-center gap-4">
          <div
            class="flex items-center justify-center overflow-hidden border rounded-lg size-20 border-n-weak bg-n-slate-2"
          >
            <img
              v-if="profile.logo_url"
              :src="profile.logo_url"
              :alt="$t('COMMERCE.COMPANY.LOGO')"
              class="object-contain w-full h-full"
            />
            <span v-else class="i-lucide-image text-n-slate-8 size-8" />
          </div>
          <div class="flex flex-wrap gap-2">
            <Button
              sm
              slate
              outline
              icon="i-lucide-upload"
              :label="$t('COMMERCE.COMPANY.UPLOAD_LOGO')"
              :is-loading="isUploadingLogo"
              @click="logoInput.click()"
            />
            <Button
              v-if="profile.logo_url"
              sm
              ruby
              link
              :label="$t('COMMERCE.COMPANY.REMOVE_LOGO')"
              @click="saveProfile({ remove_logo: true })"
            />
            <input
              ref="logoInput"
              type="file"
              :accept="IMAGE_TYPES"
              class="hidden"
              @change="onLogo"
            />
          </div>
        </div>
        <div class="grid gap-3 sm:grid-cols-2">
          <Input
            v-for="field in PROFILE_FIELDS"
            :key="field"
            v-model="profile[field]"
            :label="$t(`COMMERCE.COMPANY.FIELDS.${field}`)"
            :placeholder="$t(`COMMERCE.COMPANY.PLACEHOLDERS.${field}`)"
          />
        </div>
        <TextArea
          v-model="profile.address"
          :label="$t('COMMERCE.COMPANY.FIELDS.address')"
          :max-length="500"
        />
        <label
          class="flex flex-col gap-1 text-label-small text-n-slate-11 sm:w-1/2"
        >
          {{ $t('COMMERCE.COMPANY.FIELDS.default_currency') }}
          <Select
            v-model="profile.default_currency"
            :options="currencyOptions"
          />
        </label>
        <TextArea
          v-model="profile.default_terms"
          :label="$t('COMMERCE.COMPANY.FIELDS.default_terms')"
          :placeholder="$t('COMMERCE.COMPANY.PLACEHOLDERS.default_terms')"
          :max-length="5000"
        />
        <TextArea
          v-model="profile.footer"
          :label="$t('COMMERCE.COMPANY.FIELDS.footer')"
          :placeholder="$t('COMMERCE.COMPANY.PLACEHOLDERS.footer')"
          :max-length="1000"
        />
        <div class="flex justify-end">
          <Button
            :label="$t('COMMERCE.SAVE')"
            :is-loading="isSaving"
            @click="saveProfile()"
          />
        </div>
      </section>

      <section class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak">
        <div class="flex flex-col gap-1">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('COMMERCE.STOREFRONT.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ $t('COMMERCE.STOREFRONT.DESCRIPTION') }}
          </p>
        </div>
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <Checkbox
            :model-value="profile.storefront_enabled"
            @update:model-value="toggleStorefront"
          />
          {{ $t('COMMERCE.STOREFRONT.ENABLE') }}
        </label>
        <div
          v-if="profile.storefront_enabled && profile.storefront_url"
          class="flex flex-wrap items-center gap-2"
        >
          <a
            :href="profile.storefront_url"
            target="_blank"
            rel="noopener"
            class="flex-1 min-w-0 text-sm truncate text-n-blue-11"
          >
            {{ profile.storefront_url }}
          </a>
          <Button
            sm
            slate
            outline
            icon="i-lucide-copy"
            :label="$t('COMMERCE.STOREFRONT.COPY')"
            @click="copyStorefront"
          />
        </div>
        <p
          v-if="profile.storefront_enabled && !profile.whatsapp"
          class="text-xs text-n-amber-11"
        >
          {{ $t('COMMERCE.STOREFRONT.NO_WHATSAPP') }}
        </p>
      </section>

      <section class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak">
        <div class="flex flex-col gap-1">
          <h2 class="text-heading-3 text-n-slate-12">
            {{ $t('COMMERCE.ONLINE.TITLE') }}
          </h2>
          <p class="text-sm text-n-slate-11">
            {{ $t('COMMERCE.ONLINE.DESCRIPTION') }}
          </p>
        </div>
        <div
          v-for="(config, key) in ONLINE_PROVIDERS"
          :key="key"
          class="flex flex-wrap items-start justify-between gap-3 p-3 border rounded-lg border-n-weak"
        >
          <div class="flex flex-col min-w-0 gap-1">
            <span class="flex items-center gap-2 font-medium text-n-slate-12">
              {{ providerLabel(key) }}
              <span
                v-if="providerFor(key)"
                class="px-1.5 py-0.5 text-xs rounded-md"
                :class="
                  providerFor(key).active
                    ? 'bg-n-teal-3 text-n-teal-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{
                  providerFor(key).active
                    ? $t('COMMERCE.ONLINE.ACTIVE')
                    : $t('COMMERCE.ONLINE.INACTIVE')
                }}
              </span>
            </span>
            <span class="text-sm text-n-slate-11">
              {{
                providerFor(key)
                  ? $t('COMMERCE.ONLINE.CONNECTED_AS', {
                      environment: $t(
                        `COMMERCE.ONLINE.ENVIRONMENT.${providerFor(key).environment}`
                      ),
                      key: providerFor(key).credential_hint,
                    })
                  : $t('COMMERCE.ONLINE.NOT_CONNECTED')
              }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                $t('COMMERCE.ONLINE.CURRENCIES', {
                  currencies: config.currencies.join(', '),
                })
              }}
            </span>
            <span
              v-if="providerWithoutMethod(key)"
              class="text-xs text-n-amber-11"
            >
              {{
                $t('COMMERCE.ONLINE.NO_METHOD', {
                  provider: providerLabel(key),
                })
              }}
            </span>
            <span
              v-if="config.webhookSecret && providerFor(key)"
              class="text-xs break-all text-n-slate-11"
            >
              {{
                $t('COMMERCE.ONLINE.WEBHOOK_URL', {
                  url: providerFor(key).webhook_url,
                })
              }}
            </span>
            <span
              v-if="config.webhookSecret && providerFor(key)"
              class="text-xs text-n-slate-11"
            >
              {{ $t('COMMERCE.ONLINE.WEBHOOK_SUBSCRIPTIONS') }}
            </span>
          </div>
          <div class="flex flex-wrap gap-2">
            <Button
              sm
              :label="
                providerFor(key)
                  ? $t('COMMERCE.ONLINE.CHANGE_KEY')
                  : $t('COMMERCE.ONLINE.CONNECT')
              "
              @click="openProvider(key)"
            />
            <Button
              v-if="providerFor(key)"
              sm
              slate
              outline
              :label="
                providerFor(key).active
                  ? $t('COMMERCE.ONLINE.DISABLE')
                  : $t('COMMERCE.ONLINE.ENABLE')
              "
              @click="toggleProvider(providerFor(key))"
            />
          </div>
        </div>
        <p class="text-xs text-n-slate-11">
          {{ $t('COMMERCE.ONLINE.HOW_TO') }}
        </p>
      </section>

      <section class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak">
        <div class="flex items-center justify-between gap-2">
          <div class="flex flex-col gap-1">
            <h2 class="text-heading-3 text-n-slate-12">
              {{ $t('COMMERCE.PAYMENT_METHODS.TITLE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ $t('COMMERCE.PAYMENT_METHODS.DESCRIPTION') }}
            </p>
          </div>
          <Button
            sm
            icon="i-lucide-plus"
            :label="$t('COMMERCE.PAYMENT_METHODS.NEW')"
            @click="openMethod()"
          />
        </div>
        <p v-if="!methods.length" class="text-sm text-n-slate-11">
          {{ $t('COMMERCE.PAYMENT_METHODS.EMPTY') }}
        </p>
        <div
          v-for="row in methods"
          :key="row.id"
          class="flex items-start gap-2 p-3 border rounded-lg border-n-weak hover:border-n-strong"
        >
          <button
            type="button"
            class="flex items-start justify-between flex-1 min-w-0 gap-3 text-start"
            @click="openMethod(row)"
          >
            <div class="flex flex-col min-w-0 gap-0.5">
              <span class="font-medium text-n-slate-12">{{ row.name }}</span>
              <span class="text-xs text-n-slate-11">
                {{ $t(`COMMERCE.PAYMENT_KIND.${row.kind}`) }}
                <template v-if="row.provider_id">
                  ·
                  {{
                    $t('COMMERCE.PAYMENT_METHODS.ONLINE_BADGE', {
                      provider: providerName(row.provider_id),
                    })
                  }}
                </template>
              </span>
              <span
                v-if="row.instructions"
                class="text-sm text-n-slate-11 line-clamp-2 whitespace-pre-line"
              >
                {{ row.instructions }}
              </span>
            </div>
            <span
              v-if="!row.active"
              class="px-1.5 py-0.5 text-xs rounded-md bg-n-slate-3 text-n-slate-11 shrink-0"
            >
              {{ $t('COMMERCE.PAYMENT_METHODS.INACTIVE') }}
            </span>
          </button>
          <Button
            xs
            slate
            ghost
            icon="i-lucide-trash-2"
            :aria-label="$t('COMMERCE.PAYMENT_METHODS.DELETE')"
            :title="$t('COMMERCE.PAYMENT_METHODS.DELETE')"
            @click="confirmDeleteMethod(row)"
          />
        </div>
      </section>
    </div>

    <Dialog
      ref="methodDialog"
      overflow-y-auto
      :title="
        method.id
          ? $t('COMMERCE.PAYMENT_METHODS.EDIT')
          : $t('COMMERCE.PAYMENT_METHODS.NEW')
      "
      :confirm-button-label="$t('COMMERCE.SAVE')"
      :disable-confirm-button="!method.name?.trim()"
      :is-loading="isSavingMethod"
      @confirm="saveMethod"
    >
      <div class="flex flex-col gap-3">
        <Input
          v-model="method.name"
          :label="$t('COMMERCE.PAYMENT_METHODS.NAME')"
          :placeholder="$t('COMMERCE.PAYMENT_METHODS.NAME_PLACEHOLDER')"
        />
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('COMMERCE.PAYMENT_METHODS.KIND') }}
          <Select v-model="method.kind" :options="kindOptions" />
        </label>
        <label
          v-if="providers.length"
          class="flex flex-col gap-1 text-label-small text-n-slate-11"
        >
          {{ $t('COMMERCE.PAYMENT_METHODS.ONLINE_PROVIDER') }}
          <Select v-model="method.provider_id" :options="providerOptions" />
        </label>
        <TextArea
          v-model="method.instructions"
          :label="$t('COMMERCE.PAYMENT_METHODS.INSTRUCTIONS')"
          :placeholder="$t('COMMERCE.PAYMENT_METHODS.INSTRUCTIONS_PLACEHOLDER')"
          :max-length="2000"
        />
        <label class="flex items-center gap-2 text-sm text-n-slate-12">
          <Checkbox v-model="method.active" />
          {{ $t('COMMERCE.PAYMENT_METHODS.ACTIVE') }}
        </label>
        <div v-if="method.id" class="flex justify-end">
          <Button
            sm
            ruby
            link
            icon="i-lucide-trash-2"
            :label="$t('COMMERCE.PAYMENT_METHODS.DELETE')"
            @click="confirmDeleteMethod(method)"
          />
        </div>
      </div>
    </Dialog>

    <Dialog
      ref="deleteMethodDialog"
      type="alert"
      :title="
        $t('COMMERCE.PAYMENT_METHODS.DELETE_TITLE', {
          name: methodToDelete.name,
        })
      "
      :description="$t('COMMERCE.PAYMENT_METHODS.DELETE_DESCRIPTION')"
      :confirm-button-label="$t('COMMERCE.PAYMENT_METHODS.DELETE')"
      @confirm="deleteMethod"
    />

    <Dialog
      ref="providerDialog"
      overflow-y-auto
      :title="
        $t('COMMERCE.ONLINE.CONNECT_TITLE', {
          provider: providerLabel(editingProvider),
        })
      "
      :confirm-button-label="$t('COMMERCE.ONLINE.SAVE_KEY')"
      :disable-confirm-button="!providerFormReady"
      :is-loading="isConnecting"
      @confirm="connectProvider"
    >
      <div class="flex flex-col gap-3">
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('COMMERCE.ONLINE.ENVIRONMENT_LABEL') }}
          <Select
            v-model="providerForm.environment"
            :options="environmentOptions"
          />
        </label>
        <Input
          v-for="field in editingConfig.fields"
          :key="field.key"
          v-model="providerForm.credentials[field.key]"
          :type="field.secret ? 'password' : 'text'"
          autocomplete="off"
          :label="$t(`COMMERCE.ONLINE.CREDENTIAL.${field.key}`)"
          :placeholder="field.placeholder"
        />
        <p class="text-xs text-n-slate-11">
          {{
            $t(`COMMERCE.ONLINE.KEY_HELP.${editingProvider}`, {
              url: installationUrl,
            })
          }}
        </p>
        <template v-if="editingConfig.webhookSecret">
          <Input
            v-model="providerForm.webhook_secret"
            type="password"
            autocomplete="off"
            :label="$t('COMMERCE.ONLINE.WEBHOOK_SECRET')"
          />
          <p class="text-xs text-n-slate-11">
            {{ $t('COMMERCE.ONLINE.WEBHOOK_SECRET_HELP') }}
          </p>
        </template>
      </div>
    </Dialog>
  </section>
</template>
