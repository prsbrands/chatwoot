/* global axios */
import ApiClient from '../ApiClient';

class OpenwaAPI extends ApiClient {
  constructor() {
    super('integrations/openwa/sessions', { accountScoped: true });
  }

  qr(sessionId) {
    return axios.get(`${this.url}/${sessionId}/qr`);
  }

  start(sessionId) {
    return axios.post(`${this.url}/${sessionId}/start`);
  }

  stop(sessionId) {
    return axios.post(`${this.url}/${sessionId}/stop`);
  }

  logout(sessionId) {
    return axios.post(`${this.url}/${sessionId}/logout`);
  }
}

export default new OpenwaAPI();
