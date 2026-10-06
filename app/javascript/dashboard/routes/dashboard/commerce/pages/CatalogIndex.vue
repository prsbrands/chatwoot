<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import CommerceAPI from 'dashboard/api/commerce';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ItemDialog from '../components/ItemDialog.vue';
import CategoriesDialog from '../components/CategoriesDialog.vue';
import { KINDS, formatPrice } from '../constants';

// Catálogo da conta: produtos e serviços, com foto, preço (ou "sob orçamento")
// e categoria. Todos consultam; só admin cadastra.
const { t } = useI18n();
const { isAdmin } = useAdmin();
const { accountScopedRoute } = useAccount();

const ALL = '';
const items = ref([]);
const categories = ref([]);
const defaultCurrency = ref('USD');
const isLoading = ref(true);
const search = ref('');
const kind = ref(ALL);
const categoryId = ref(ALL);
const itemDialog = ref(null);
const categoriesDialog = ref(null);

const kindOptions = computed(() => [
  { value: ALL, label: t('COMMERCE.CATALOG.ALL_KINDS') },
  ...KINDS.map(k => ({ value: k, label: t(`COMMERCE.KIND.${k}`) })),
]);
const categoryOptions = computed(() => [
  { value: ALL, label: t('COMMERCE.CATALOG.ALL_CATEGORIES') },
  ...categories.value.map(c => ({ value: c.id, label: c.name })),
]);

const fetchItems = async () => {
  try {
    const { data } = await CommerceAPI.items({
      q: search.value.trim() || undefined,
      kind: kind.value || undefined,
      category_id: categoryId.value || undefined,
    });
    items.value = data.payload;
  } catch (error) {
    useAlert(t('COMMERCE.API.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const fetchCategories = async () => {
  const { data } = await CommerceAPI.categories();
  categories.value = data.payload;
};

const onCategoriesChanged = async () => {
  await fetchCategories();
  await fetchItems();
};

let searchTimer = null;
watch(search, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(fetchItems, 300);
});
watch([kind, categoryId], fetchItems);

const priceLine = item => {
  if (item.price === null) return t('COMMERCE.CATALOG.ON_QUOTE');
  const price = formatPrice(item.price, item.currency);
  return item.billing_interval === 'one_time'
    ? t('COMMERCE.CATALOG.PRICE_PER_UNIT', {
        price,
        unit: t(`COMMERCE.UNIT.${item.unit}`),
      })
    : t(`COMMERCE.CATALOG.PRICE_PER_${item.billing_interval.toUpperCase()}`, {
        price,
      });
};

const openItem = item => {
  if (isAdmin.value) itemDialog.value.open(item);
};

onMounted(async () => {
  const [, profile] = await Promise.all([
    fetchCategories(),
    CommerceAPI.profile(),
  ]);
  defaultCurrency.value = profile.data.default_currency;
  await fetchItems();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header
      class="flex flex-wrap items-start justify-between gap-4 px-6 py-5 border-b border-n-weak"
    >
      <div class="flex flex-col min-w-0 gap-1">
        <h1 class="text-heading-2 text-n-slate-12">
          {{ $t('COMMERCE.CATALOG.HEADER') }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t('COMMERCE.CATALOG.SUBTITLE') }}
        </p>
      </div>
      <div v-if="isAdmin" class="flex flex-wrap items-center gap-2">
        <router-link :to="accountScopedRoute('commerce_company')">
          <Button
            sm
            slate
            outline
            icon="i-lucide-building-2"
            :label="$t('COMMERCE.COMPANY.HEADER')"
          />
        </router-link>
        <Button
          sm
          slate
          outline
          icon="i-lucide-folder-tree"
          :label="$t('COMMERCE.CATEGORIES.TITLE')"
          @click="categoriesDialog.open()"
        />
        <Button
          sm
          icon="i-lucide-plus"
          :label="$t('COMMERCE.CATALOG.NEW')"
          @click="itemDialog.open()"
        />
      </div>
    </header>

    <div class="flex flex-wrap items-center gap-2 px-6 pt-4">
      <Input
        v-model="search"
        class="w-64"
        :placeholder="$t('COMMERCE.CATALOG.SEARCH')"
      />
      <Select v-model="kind" :options="kindOptions" class="w-40" />
      <Select v-model="categoryId" :options="categoryOptions" class="w-48" />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 px-6 py-5 text-sm text-n-slate-11"
    >
      <Spinner />
      {{ $t('COMMERCE.CATALOG.LOADING') }}
    </div>
    <p v-else-if="!items.length" class="px-6 py-5 text-sm text-n-slate-11">
      {{ $t('COMMERCE.CATALOG.EMPTY') }}
    </p>
    <div
      v-else
      class="grid gap-4 px-6 py-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
    >
      <button
        v-for="item in items"
        :key="item.id"
        type="button"
        class="flex flex-col overflow-hidden text-start border rounded-xl border-n-weak bg-n-solid-1"
        :class="{
          'hover:border-n-strong': isAdmin,
          'cursor-default': !isAdmin,
        }"
        @click="openItem(item)"
      >
        <div
          class="flex items-center justify-center w-full aspect-[4/3] bg-n-slate-2"
        >
          <img
            v-if="item.images.length"
            :src="item.images[0].url"
            :alt="item.name"
            class="object-cover w-full h-full"
          />
          <span
            v-else
            class="text-n-slate-8 size-10"
            :class="
              item.kind === 'service' ? 'i-lucide-wrench' : 'i-lucide-package'
            "
          />
        </div>
        <div class="flex flex-col gap-1 p-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-medium text-n-slate-11">
              {{ $t(`COMMERCE.KIND.${item.kind}`) }}
            </span>
            <span v-if="item.category_name" class="text-xs text-n-slate-10">
              · {{ item.category_name }}
            </span>
            <span
              v-if="!item.available"
              class="px-1.5 py-0.5 text-xs rounded-md bg-n-amber-3 text-n-amber-11 ms-auto"
            >
              {{ $t('COMMERCE.CATALOG.UNAVAILABLE') }}
            </span>
          </div>
          <span class="font-medium text-n-slate-12 line-clamp-2">
            {{ item.name }}
          </span>
          <span class="text-sm text-n-slate-11">{{ priceLine(item) }}</span>
        </div>
      </button>
    </div>

    <ItemDialog
      ref="itemDialog"
      :categories="categories"
      :default-currency="defaultCurrency"
      @saved="fetchItems"
    />
    <CategoriesDialog
      ref="categoriesDialog"
      :categories="categories"
      @changed="onCategoriesChanged"
    />
  </section>
</template>
