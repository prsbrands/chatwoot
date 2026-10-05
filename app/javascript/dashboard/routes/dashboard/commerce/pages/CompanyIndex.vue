<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { CURRENCIES, IMAGE_TYPES, PAYMENT_KINDS } from '../constants';

// Os dados da empresa que saem nos orçamentos e faturas (fase 2) e as formas
// de pagamento que a conta aceita, com as instruções ao cliente.
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
];

const profile = ref({});
const methods = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isUploadingLogo = ref(false);
const logoInput = ref(null);
const methodDialog = ref(null);
const method = ref({});

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
        position: methods.value.length,
      };
  methodDialog.value.open();
};

const saveMethod = async () => {
  const payload = { ...method.value, name: method.value.name.trim() };
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
  }
};

const deleteMethod = async () => {
  try {
    await CommerceAPI.deletePaymentMethod(method.value.id);
    methodDialog.value.close();
    await fetchMethods();
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  }
};

onMounted(async () => {
  try {
    const [{ data }] = await Promise.all([
      CommerceAPI.profile(),
      fetchMethods(),
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
          <Select v-model="profile.default_currency" :options="currencyOptions" />
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
        <button
          v-for="row in methods"
          :key="row.id"
          type="button"
          class="flex items-start justify-between gap-3 p-3 text-start border rounded-lg border-n-weak hover:border-n-strong"
          @click="openMethod(row)"
        >
          <div class="flex flex-col min-w-0 gap-0.5">
            <span class="font-medium text-n-slate-12">{{ row.name }}</span>
            <span class="text-xs text-n-slate-11">
              {{ $t(`COMMERCE.PAYMENT_KIND.${row.kind}`) }}
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
            @click="deleteMethod"
          />
        </div>
      </div>
    </Dialog>
  </section>
</template>
