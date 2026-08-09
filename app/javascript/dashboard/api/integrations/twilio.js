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

  sipDomains() {
    return axios.get(`${this.url}/sip`);
  }

  createSipDomain(subdomain) {
    return axios.post(`${this.url}/sip`, { subdomain });
  }

  sipCredentials(domainSid) {
    return axios.get(`${this.url}/sip/${domainSid}/credentials`);
  }

  createSipCredential(domainSid, username) {
    return axios.post(`${this.url}/sip/${domainSid}/create_credential`, {
      username,
    });
  }

  deleteSipCredential(domainSid, credentialSid) {
    return axios.delete(`${this.url}/sip/${domainSid}/destroy_credential`, {
      params: { credential_sid: credentialSid },
    });
  }

  voiceRoutes() {
    return axios.get(`${this.url}/voice_routes`);
  }

  saveVoiceRoute(data) {
    return axios.post(`${this.url}/voice_routes`, data);
  }

  deleteVoiceRoute(id) {
    return axios.delete(`${this.url}/voice_routes/${id}`);
  }
}

export default new TwilioAPI();
