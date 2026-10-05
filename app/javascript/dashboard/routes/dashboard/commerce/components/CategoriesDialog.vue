<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import CommerceAPI from 'dashboard/api/commerce';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

// Categorias do catálogo: criar, renomear (ao sair do campo) e apagar. Os itens
// de uma categoria apagada ficam sem categoria.
const props = defineProps({
  categories: { type: Array, default: () => [] },
});
const emit = defineEmits(['changed']);

const { t } = useI18n();
const dialogRef = ref(null);
const newName = ref('');

const run = async request => {
  try {
    await request();
    emit('changed');
  } catch (error) {
    useAlert(error.response?.data?.message || t('COMMERCE.API.ERROR'));
  }
};

const add = () =>
  run(async () => {
    await CommerceAPI.createCategory({
      name: newName.value.trim(),
      position: props.categories.length,
    });
    newName.value = '';
  });

const rename = (category, name) => {
  if (!name.trim() || name.trim() === category.name) return;
  run(() => CommerceAPI.updateCategory(category.id, { name: name.trim() }));
};

const remove = category => run(() => CommerceAPI.deleteCategory(category.id));

defineExpose({ open: () => dialogRef.value.open() });
</script>

<template>
  <Dialog
    ref="dialogRef"
    overflow-y-auto
    :title="$t('COMMERCE.CATEGORIES.TITLE')"
    :description="$t('COMMERCE.CATEGORIES.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="$t('COMMERCE.CLOSE')"
  >
    <div class="flex flex-col gap-2">
      <div
        v-for="category in categories"
        :key="category.id"
        class="flex items-center gap-2"
      >
        <Input
          :model-value="category.name"
          class="flex-1"
          @blur="event => rename(category, event.target.value)"
        />
        <Button
          sm
          ruby
          ghost
          icon="i-lucide-trash-2"
          :aria-label="$t('COMMERCE.CATEGORIES.DELETE')"
          @click="remove(category)"
        />
      </div>
      <div class="flex items-center gap-2 pt-2 border-t border-n-weak">
        <Input
          v-model="newName"
          class="flex-1"
          :placeholder="$t('COMMERCE.CATEGORIES.NEW_PLACEHOLDER')"
          @enter="newName.trim() && add()"
        />
        <Button
          sm
          icon="i-lucide-plus"
          :label="$t('COMMERCE.CATEGORIES.ADD')"
          :disabled="!newName.trim()"
          @click="add"
        />
      </div>
    </div>
  </Dialog>
</template>
