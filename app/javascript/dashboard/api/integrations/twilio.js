/* global axios */
import ApiClient from '../ApiClient';

class TwilioAPI extends ApiClient {
  constructor() {
    super('integrations/twilio', { accountScoped: true });
  }

  credentials() {
    return axios.get(`${this.url}/credentials`);
  }

  connect(data) {
    return axios.post(`${this.url}/credentials`, data);
  }

  disconnect() {
    return axios.delete(`${this.url}/credentials`);
  }

  numbers({ search, pageUrl } = {}) {
    return axios.get(`${this.url}/numbers`, {
      params: { search: search || undefined, page_url: pageUrl || undefined },
    });
  }

  provisionSms(data) {
    return axios.post(`${this.url}/numbers`, data);
  }
}

export default new TwilioAPI();
