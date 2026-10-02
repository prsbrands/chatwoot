<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { usePolicy } from 'dashboard/composables/usePolicy';
import Icon from 'next/icon/Icon.vue';
import { HUBS } from '../catalog';

const route = useRoute();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const { shouldShow } = usePolicy();

const hubId = computed(() => route.meta.hub);
const prefix = computed(() => `HUBS.${hubId.value.toUpperCase()}`);

const linkFor = item => accountScopedRoute(item.to, {}, item.query);

// Mesma regra do menu: a rota de destino diz quem pode abrir a tela.
const canOpen = item => {
  const { meta } = router.resolve(linkFor(item));
  return shouldShow(
    meta.featureFlag || '',
    meta.permissions || [],
    meta.installationTypes || []
  );
};

const sections = computed(() =>
  HUBS[hubId.value].sections
    .map(section => ({ ...section, items: section.items.filter(canOpen) }))
    .filter(section => section.items.length)
);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <div class="flex flex-col w-full max-w-5xl gap-8 px-6 py-8 mx-auto">
      <header class="flex flex-col gap-1">
        <h1 class="text-heading-1 text-n-slate-12">
          {{ $t(`${prefix}.HEADER`) }}
        </h1>
        <p class="text-body-main text-n-slate-11">
          {{ $t(`${prefix}.DESCRIPTION`) }}
        </p>
      </header>

      <section
        v-for="section in sections"
        :key="section.id"
        class="flex flex-col gap-3"
      >
        <h2 class="text-xs font-medium tracking-wide uppercase text-n-slate-11">
          {{ $t(`${prefix}.SECTION.${section.id}`) }}
        </h2>
        <div class="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
          <router-link
            v-for="item in section.items"
            :key="item.id"
            :to="linkFor(item)"
            class="flex gap-3 p-4 rounded-xl bg-n-card outline outline-1 outline-n-container hover:outline-n-strong"
          >
            <Icon :icon="item.icon" class="size-5 shrink-0 text-n-slate-11" />
            <span class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-12">
                {{ $t(`${prefix}.ITEMS.${item.id}.TITLE`) }}
              </span>
              <span class="text-xs text-n-slate-11">
                {{ $t(`${prefix}.ITEMS.${item.id}.DESCRIPTION`) }}
              </span>
            </span>
          </router-link>
        </div>
      </section>
    </div>
  </section>
</template>
