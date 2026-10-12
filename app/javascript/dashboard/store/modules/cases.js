import CasesAPI from '../../api/cases';

// Casos no sidebar: o número vermelho são os casos com o prazo vencido.
const SET_OVERDUE_COUNT = 'SET_CASES_OVERDUE_COUNT';

export const state = {
  overdueCount: 0,
};

export const getters = {
  getOverdueCount: $state => $state.overdueCount,
};

export const actions = {
  fetchOverdueCount: async ({ commit }) => {
    const { data } = await CasesAPI.overdueCount();
    commit(SET_OVERDUE_COUNT, data.count);
  },
};

export const mutations = {
  [SET_OVERDUE_COUNT]($state, count) {
    $state.overdueCount = count;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
