import CommerceAPI from '../../api/commerce';

// Comercial no sidebar: o número vermelho em Quotes & invoices são os
// rascunhos de cotização que a IA preparou e ninguém enviou ainda.
const SET_REVIEW_COUNT = 'SET_COMMERCE_REVIEW_COUNT';

export const state = {
  reviewCount: 0,
};

export const getters = {
  getReviewCount: $state => $state.reviewCount,
};

export const actions = {
  fetchReviewCount: async ({ commit }) => {
    const { data } = await CommerceAPI.reviewCount();
    commit(SET_REVIEW_COUNT, data.count);
  },
};

export const mutations = {
  [SET_REVIEW_COUNT]($state, count) {
    $state.reviewCount = count;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
