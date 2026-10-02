import BotlayerAPI from '../../api/integrations/botlayer';

// Saúde dos canais: a tela Conexões e o ponto de alerta no sidebar leem daqui.
// A queda do WhatsApp vem das próprias inboxes (reauthorization_required); o
// bot mudo vem do endpoint de saúde do botlayer.
export const BOT_PROBLEMS = [
  'bot_without_route',
  'stale_credentials',
  'route_without_bot',
];

const SET_HEALTH = 'SET_CONNECTIONS_HEALTH';

export const state = {
  health: [],
};

export const getters = {
  getHealth: $state => $state.health,
  getInboxHealth: $state => inboxId =>
    $state.health.find(item => item.inbox_id === inboxId),
  hasProblems: ($state, _getters, _rootState, rootGetters) =>
    $state.health.some(item => BOT_PROBLEMS.includes(item.status)) ||
    rootGetters['inboxes/getInboxes'].some(
      inbox => inbox.reauthorization_required
    ),
};

export const actions = {
  fetchHealth: async ({ commit }) => {
    const { data } = await BotlayerAPI.health();
    commit(SET_HEALTH, data.inboxes);
  },
};

export const mutations = {
  [SET_HEALTH]($state, health) {
    $state.health = health;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
