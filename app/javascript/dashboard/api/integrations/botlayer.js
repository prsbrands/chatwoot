/* global axios */
import ApiClient from '../ApiClient';

class BotlayerAPI extends ApiClient {
  constructor() {
    super('integrations/botlayer', { accountScoped: true });
  }

  personas() {
    return axios.get(`${this.url}/personas`);
  }

  createPersona(data) {
    return axios.post(`${this.url}/personas`, data);
  }

  updatePersona(id, data) {
    return axios.patch(`${this.url}/personas/${id}`, data);
  }

  deletePersona(id) {
    return axios.delete(`${this.url}/personas/${id}`);
  }

  knowledge() {
    return axios.get(`${this.url}/knowledge`);
  }

  createKnowledge(data) {
    return axios.post(`${this.url}/knowledge`, data);
  }

  updateKnowledge(id, data) {
    return axios.patch(`${this.url}/knowledge/${id}`, data);
  }

  deleteKnowledge(id) {
    return axios.delete(`${this.url}/knowledge/${id}`);
  }

  routes() {
    return axios.get(`${this.url}/routes`);
  }

  upsertRoute(data) {
    return axios.post(`${this.url}/routes`, data);
  }

  deleteRoute(id) {
    return axios.delete(`${this.url}/routes/${id}`);
  }
}

export default new BotlayerAPI();
