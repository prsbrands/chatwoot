import OutreachAPI from '../../api/outreach';

// Campanhas por QR no sidebar: o número são as campanhas que o sistema pausou
// (sessão caída, falhas de envio) e esperam alguém.
const SET_ATTENTION_COUNT = 'SET_OUTREACH_ATTENTION_COUNT';

export const state = {
  attentionCount: 0,
};

export const getters = {
  getAttentionCount: $state => $state.attentionCount,
};

export const actions = {
  fetchAttentionCount: async ({ commit }) => {
    const { data } = await OutreachAPI.attentionCount();
    commit(SET_ATTENTION_COUNT, data.count);
  },
};

export const mutations = {
  [SET_ATTENTION_COUNT]($state, count) {
    $state.attentionCount = count;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
