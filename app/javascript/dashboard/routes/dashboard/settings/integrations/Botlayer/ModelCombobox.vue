<script setup>
import { computed, ref } from 'vue';

const props = defineProps({
  models: { type: Array, default: () => [] },
  placeholder: { type: String, default: 'provider/model-id' },
});

const model = defineModel({ type: String, default: '' });

const isOpen = ref(false);

// Filtra pelo que já está digitado, mas nunca esconde tudo: com o campo
// preenchido por uma escolha anterior, a lista completa continua acessível.
const suggestions = computed(() => {
  const query = String(model.value || '').toLowerCase();
  if (!query) return props.models;
  const filtered = props.models.filter(id => id.toLowerCase().includes(query));
  return filtered.length ? filtered : props.models;
});

const pick = id => {
  model.value = id;
  isOpen.value = false;
};
</script>

<template>
  <div class="relative">
    <input
      v-model="model"
      class="h-10 w-full rounded-lg border border-n-weak bg-n-alpha-black2 px-3 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
      :placeholder="placeholder"
      @focus="isOpen = true"
      @blur="isOpen = false"
    />
    <div
      v-if="isOpen && suggestions.length"
      class="absolute top-full z-20 mt-1 max-h-64 w-full overflow-y-auto rounded-lg border border-n-weak bg-n-solid-1 shadow-lg"
    >
      <button
        v-for="id in suggestions"
        :key="id"
        class="block w-full truncate px-3 py-1.5 text-left text-sm text-n-slate-12 hover:bg-n-alpha-1"
        @mousedown.prevent="pick(id)"
      >
        {{ id }}
      </button>
    </div>
  </div>
</template>
