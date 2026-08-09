/* global axios */
import ApiClient from '../ApiClient';

class TwilioAPI extends ApiClient {
  constructor() {
    super('integrations/twilio', { accountScoped: true });
  }

  get credentials() {
    return axios.get(`${this.url}/credentials`);
  }

  connect(data) {
    return axios.post(`${this.url}/credentials`, data);
  }

  disconnect() {
    return axios.delete(`${this.url}/credentials`);
  }

  numbers() {
    return axios.get(`${this.url}/numbers`);
  }
}

export default new TwilioAPI();
