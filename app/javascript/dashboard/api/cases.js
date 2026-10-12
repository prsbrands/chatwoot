/* global axios */
import ApiClient from './ApiClient';

// Casos (flag `cases`): tipos com campos próprios, casos, histórico e o número
// de atrasados do menu.
class CasesAPI extends ApiClient {
  constructor() {
    super('cases', { accountScoped: true });
  }

  list(params) {
    return axios.get(this.url, { params });
  }

  metrics(days) {
    return axios.get(`${this.url}/metrics`, { params: { days } });
  }

  overdueCount() {
    return axios.get(`${this.url}/overdue_count`);
  }

  action(id, action, payload = {}) {
    return axios.post(`${this.url}/${id}/${action}`, payload);
  }

  types() {
    return axios.get(`${this.url}/types`);
  }

  createType(type) {
    return axios.post(`${this.url}/types`, type);
  }

  updateType(id, type) {
    return axios.patch(`${this.url}/types/${id}`, type);
  }

  deleteType(id) {
    return axios.delete(`${this.url}/types/${id}`);
  }

  settings() {
    return axios.get(`${this.url}/settings`);
  }

  updateSettings(settings) {
    return axios.patch(`${this.url}/settings`, settings);
  }
}

export default new CasesAPI();
