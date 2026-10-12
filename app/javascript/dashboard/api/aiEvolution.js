/* global axios */
import ApiClient from './ApiClient';

// Evolução da IA (flag `ai_evolution`): as propostas para a base e o prompt
// que a rodada diária tira das conversas, e a evolução por semana.
class AiEvolutionAPI extends ApiClient {
  constructor() {
    super('ai_evolution/suggestions', { accountScoped: true });
  }

  list(params) {
    return axios.get(this.url, { params });
  }

  action(id, action, payload = {}) {
    return axios.post(`${this.url}/${id}/${action}`, payload);
  }

  pendingCount() {
    return axios.get(`${this.url}/pending_count`);
  }

  progress() {
    return axios.get(`${this.url}/progress`);
  }
}

export default new AiEvolutionAPI();
