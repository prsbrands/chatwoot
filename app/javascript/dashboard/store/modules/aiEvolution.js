import AiEvolutionAPI from '../../api/aiEvolution';

// Evolução da IA no sidebar: o número são as propostas esperando revisão.
const SET_PENDING_COUNT = 'SET_AI_EVOLUTION_PENDING_COUNT';

export const state = {
  pendingCount: 0,
};

export const getters = {
  getPendingCount: $state => $state.pendingCount,
};

export const actions = {
  fetchPendingCount: async ({ commit }) => {
    const { data } = await AiEvolutionAPI.pendingCount();
    commit(SET_PENDING_COUNT, data.count);
  },
};

export const mutations = {
  [SET_PENDING_COUNT]($state, count) {
    $state.pendingCount = count;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
