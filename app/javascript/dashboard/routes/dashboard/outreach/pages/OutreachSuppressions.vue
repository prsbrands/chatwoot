<script setup>
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import OutreachAPI from 'dashboard/api/outreach';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

// Números que a operação não quer em campanha. Diferente do pedido de parar:
// quem está aqui continua sendo atendido normalmente.
const router = useRouter();
const { t } = useI18n();
const { accountScopedRoute } = useAccount();

const suppressions = ref([]);
const phones = ref('');
const reason = ref('');
const isLoading = ref(true);
const isSaving = ref(false);

const fetchAll = async () => {
  const { data } = await OutreachAPI.suppressions();
  suppressions.value = data.payload;
  isLoading.value = false;
};

const fail = error =>
  useAlert(
    error.response?.data?.message ||
      error.response?.data?.error ||
      t('OUTREACH.API.ERROR')
  );

const add = async () => {
  isSaving.value = true;
  try {
    const { data } = await OutreachAPI.addSuppressions({
      phones: phones.value,
      reason: reason.value.trim(),
    });
    useAlert(
      data.invalid.length
        ? t('OUTREACH.EXCLUSIONS.ADDED_INVALID', {
            count: data.added,
            invalid: data.invalid.join(', '),
          })
        : t('OUTREACH.EXCLUSIONS.ADDED', { count: data.added })
    );
    phones.value = '';
    reason.value = '';
    await fetchAll();
  } catch (error) {
    fail(error);
  } finally {
    isSaving.value = false;
  }
};

const remove = async id => {
  try {
    await OutreachAPI.removeSuppression(id);
    await fetchAll();
  } catch (error) {
    fail(error);
  }
};

onMounted(fetchAll);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-y-auto bg-n-surface-1">
    <header class="flex flex-col gap-1 px-6 py-5 border-b border-n-weak">
      <h1 class="text-heading-2 text-n-slate-12">
        {{ $t('OUTREACH.EXCLUSIONS.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ $t('OUTREACH.EXCLUSIONS.DESCRIPTION') }}
      </p>
    </header>
    <div class="flex flex-col max-w-xl gap-3 px-6 py-5">
      <label class="flex flex-col gap-1">
        <span class="text-sm text-n-slate-12">
          {{ $t('OUTREACH.EXCLUSIONS.PHONES') }}
        </span>
        <TextArea v-model="phones" :rows="4" />
      </label>
      <Input v-model="reason" :label="$t('OUTREACH.EXCLUSIONS.REASON')" />
      <div class="flex gap-2">
        <Button
          :label="$t('OUTREACH.EXCLUSIONS.ADD')"
          :is-loading="isSaving"
          :disabled="!phones.trim()"
          @click="add"
        />
        <Button
          slate
          faded
          :label="$t('OUTREACH.BACK')"
          @click="router.push(accountScopedRoute('outreach_index'))"
        />
      </div>
    </div>
    <div v-if="isLoading" class="flex px-6 py-5"><Spinner /></div>
    <ul v-else class="flex flex-col max-w-xl gap-2 px-6 pb-6">
      <li
        v-for="item in suppressions"
        :key="item.id"
        class="flex items-center gap-3 px-4 py-2 rounded-lg bg-n-card outline outline-1 outline-n-container"
      >
        <span class="text-sm text-n-slate-12">{{ item.phone }}</span>
        <span class="flex-1 text-xs text-n-slate-11">{{ item.reason }}</span>
        <Button
          ghost
          slate
          xs
          icon="i-lucide-trash-2"
          :label="$t('OUTREACH.EXCLUSIONS.REMOVE')"
          @click="remove(item.id)"
        />
      </li>
    </ul>
  </section>
</template>
