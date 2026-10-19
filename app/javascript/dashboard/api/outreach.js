/* global axios */
import ApiClient from './ApiClient';

// Campanhas por QR (flag `outreach`): campanhas, a lista (arquivo ou CRM), a
// preparação, o envio, os resultados e a lista de exclusão.
class OutreachAPI extends ApiClient {
  constructor() {
    super('outreach/campaigns', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  action(id, action, payload = {}) {
    return axios.post(`${this.url}/${id}/${action}`, payload);
  }

  recipients(id, params) {
    return axios.get(`${this.url}/${id}/recipients`, { params });
  }

  attentionCount() {
    return axios.get(`${this.url}/attention_count`);
  }

  previewImport(file) {
    const body = new FormData();
    body.append('file', file);
    return axios.post(`${this.url}/preview_import`, body);
  }

  // Troca a lista da campanha: contatos do CRM (filters) ou um arquivo com o
  // mapeamento das colunas.
  audience(id, { source, file, mapping, country, filters }) {
    const body = new FormData();
    body.append('source', source);
    if (file) body.append('file', file);
    Object.entries(mapping || {}).forEach(([key, value]) => {
      if (value) body.append(`mapping[${key}]`, value);
    });
    if (country) body.append('country', country);
    Object.entries(filters || {}).forEach(([key, value]) => {
      if (value) body.append(`filters[${key}]`, value);
    });
    return axios.post(`${this.url}/${id}/audience`, body);
  }

  suppressions() {
    return axios.get(`${this.baseUrl()}/outreach/suppressions`);
  }

  addSuppressions(payload) {
    return axios.post(`${this.baseUrl()}/outreach/suppressions`, payload);
  }

  removeSuppression(id) {
    return axios.delete(`${this.baseUrl()}/outreach/suppressions/${id}`);
  }
}

export default new OutreachAPI();
