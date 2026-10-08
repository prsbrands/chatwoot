/* global axios */
import ApiClient from './ApiClient';

// Memoria da IA por contato: o resumo e os fatos que a IA guarda (e que a
// equipe corrige, fixa ou escreve).
class AiMemoryAPI extends ApiClient {
  constructor() {
    super('ai_memory', { accountScoped: true });
  }

  show(contactId) {
    return axios.get(`${this.url}/contacts/${contactId}`);
  }

  updateSummary(contactId, summary) {
    return axios.patch(`${this.url}/contacts/${contactId}`, { summary });
  }

  createFact(contactId, body) {
    return axios.post(`${this.url}/facts`, { contact_id: contactId, body });
  }

  updateFact(id, fact) {
    return axios.patch(`${this.url}/facts/${id}`, fact);
  }

  deleteFact(id) {
    return axios.delete(`${this.url}/facts/${id}`);
  }
}

export default new AiMemoryAPI();
