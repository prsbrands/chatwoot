<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import {
  BILLING_INTERVALS,
  CURRENCIES,
  IMAGE_TYPES,
  KINDS,
  MAX_IMAGES,
  UNITS,
} from '../constants';

// Criar ou editar um item do catálogo. As imagens precisam do item salvo: um
// item novo fica aberto depois de criado, já com a área de imagens.
const props = defineProps({
  categories: { type: Array, default: () => [] },
  defaultCurrency: { type: String, default: 'USD' },
});
const emit = defineEmits(['saved']);

const { t } = useI18n();

const NO_CATEGORY = 0;
const dialogRef = ref(null);
const fileInput = ref(null);
const item = ref(null);
const form = ref({});
const isSaving = ref(false);
const isUploading = ref(false);

const kindOptions = computed(() =>
  KINDS.map(kind => ({ value: kind, label: t(`COMMERCE.KIND.${kind}`) }))
);
const unitOptions = computed(() =>
  UNITS.map(unit => ({ value: unit, label: t(`COMMERCE.UNIT.${unit}`) }))
);
const billingOptions = computed(() =>
  BILLING_INTERVALS.map(value => ({
    value,
    label: t(`COMMERCE.BILLING_INTERVAL.${value}`),
  }))
);
const currencyOptions = CURRENCIES.map(code => ({ value: code, label: code }));
const categoryOptions = computed(() => [
  { value: NO_CATEGORY, label: t('COMMERCE.CATALOG.NO_CATEGORY') },
  ...props.categories.map(c => ({ value: c.id, label: c.name })),
]);
const images = computed(() => item.value?.images || []);

// Apagar pede um segundo clique: o primeiro só arma o botão.
const confirmingDelete = ref(false);
const removeItem = async () => {
  if (!confirmingDelete.value) {
    confirmingDelete.value = true;
    return;
  }
  try {
    await CommerceAPI.deleteItem(item.value.id);
    emit('saved', null);
    dialogRef.value.close();
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  }
};

const open = (existing = null) => {
  item.value = existing;
  confirmingDelete.value = false;
  form.value = {
    kind: existing?.kind || 'product',
    name: existing?.name || '',
    sku: existing?.sku || '',
    description: existing?.description || '',
    price: existing?.price ?? '',
    currency: existing?.currency || props.defaultCurrency,
    unit: existing?.unit || 'unit',
    billing_interval: existing?.billing_interval || 'one_time',
    category_id: existing?.category_id || NO_CATEGORY,
    available: existing ? existing.available : true,
  };
  dialogRef.value.open();
};

const save = async () => {
  const payload = {
    ...form.value,
    name: form.value.name.trim(),
    price: form.value.price === '' ? null : form.value.price,
    category_id: form.value.category_id || null,
  };
  isSaving.value = true;
  try {
    const isNew = !item.value;
    const { data } = isNew
      ? await CommerceAPI.createItem(payload)
      : await CommerceAPI.updateItem(item.value.id, payload);
    item.value = data;
    emit('saved', data);
    if (isNew) {
      useAlert(t('COMMERCE.CATALOG.CREATED_ADD_IMAGES'));
    } else {
      dialogRef.value.close();
    }
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const pickImages = () => fileInput.value.click();

const onFiles = async event => {
  const files = [...event.target.files].slice(
    0,
    MAX_IMAGES - images.value.length
  );
  event.target.value = '';
  isUploading.value = true;
  try {
    // Em série: cada resposta traz a lista inteira de imagens do item.
    // eslint-disable-next-line no-restricted-syntax
    for (const file of files) {
      // eslint-disable-next-line no-await-in-loop
      const { blobId } = await uploadFile(file);
      // eslint-disable-next-line no-await-in-loop
      const { data } = await CommerceAPI.addItemImage(item.value.id, blobId);
      item.value = data;
    }
    emit('saved', item.value);
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  } finally {
    isUploading.value = false;
  }
};

const removeImage = async image => {
  try {
    const { data } = await CommerceAPI.removeItemImage(item.value.id, image.id);
    item.value = data;
    emit('saved', data);
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    width="2xl"
    :title="item ? $t('COMMERCE.CATALOG.EDIT') : $t('COMMERCE.CATALOG.NEW')"
    :confirm-button-label="$t('COMMERCE.SAVE')"
    :disable-confirm-button="!form.name?.trim()"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-3">
      <div class="grid gap-3 sm:grid-cols-2">
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('COMMERCE.CATALOG.KIND') }}
          <Select v-model="form.kind" :options="kindOptions" />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('COMMERCE.CATALOG.CATEGORY') }}
          <Select v-model="form.category_id" :options="categoryOptions" />
        </label>
      </div>
      <Input v-model="form.name" :label="$t('COMMERCE.CATALOG.NAME')" />
      <Input v-model="form.sku" :label="$t('COMMERCE.CATALOG.SKU')" />
      <TextArea
        v-model="form.description"
        :label="$t('COMMERCE.CATALOG.DESCRIPTION')"
        :max-length="5000"
      />
      <div class="grid gap-3 sm:grid-cols-3">
        <Input
          v-model="form.price"
          type="number"
          min="0"
          step="0.01"
          :label="$t('COMMERCE.CATALOG.PRICE')"
          :message="$t('COMMERCE.CATALOG.PRICE_HELP')"
        />
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('COMMERCE.CATALOG.CURRENCY') }}
          <Select v-model="form.currency" :options="currencyOptions" />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ $t('COMMERCE.CATALOG.UNIT') }}
          <Select v-model="form.unit" :options="unitOptions" />
        </label>
      </div>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('COMMERCE.CATALOG.BILLING') }}
        <Select v-model="form.billing_interval" :options="billingOptions" />
        <span
          v-if="form.billing_interval !== 'one_time'"
          class="text-n-slate-10"
        >
          {{ $t('COMMERCE.CATALOG.BILLING_HELP') }}
        </span>
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <Checkbox v-model="form.available" />
        {{ $t('COMMERCE.CATALOG.AVAILABLE') }}
      </label>

      <section
        v-if="item"
        class="flex flex-col gap-2 pt-2 border-t border-n-weak"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-label-small text-n-slate-11">
            {{
              $t('COMMERCE.CATALOG.IMAGES', {
                count: images.length,
                max: MAX_IMAGES,
              })
            }}
          </span>
          <Button
            sm
            slate
            outline
            icon="i-lucide-image-plus"
            :label="$t('COMMERCE.CATALOG.ADD_IMAGES')"
            :is-loading="isUploading"
            :disabled="images.length >= MAX_IMAGES"
            @click="pickImages"
          />
          <input
            ref="fileInput"
            type="file"
            multiple
            :accept="IMAGE_TYPES"
            class="hidden"
            @change="onFiles"
          />
        </div>
        <div v-if="images.length" class="grid grid-cols-3 gap-2 sm:grid-cols-5">
          <div
            v-for="image in images"
            :key="image.id"
            class="relative overflow-hidden border rounded-lg aspect-square border-n-weak group"
          >
            <img
              :src="image.url"
              :alt="image.filename"
              class="object-cover w-full h-full"
            />
            <Button
              xs
              ruby
              icon="i-lucide-trash-2"
              class="absolute top-1 end-1 opacity-0 group-hover:opacity-100"
              :aria-label="$t('COMMERCE.CATALOG.REMOVE_IMAGE')"
              @click="removeImage(image)"
            />
          </div>
        </div>
      </section>
      <div v-if="item" class="flex justify-end">
        <Button
          sm
          ruby
          link
          icon="i-lucide-trash-2"
          :label="
            confirmingDelete
              ? $t('COMMERCE.CATALOG.DELETE_CONFIRM')
              : $t('COMMERCE.CATALOG.DELETE')
          "
          @click="removeItem"
        />
      </div>
    </div>
  </Dialog>
</template>
