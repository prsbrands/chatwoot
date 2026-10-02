/* global axios */
import ApiClient from './ApiClient';

// Agenda: compromissos e a conexão da pessoa logada com o Google Calendar.
class AgendaAPI extends ApiClient {
  constructor() {
    super('agenda', { accountScoped: true });
  }

  appointments(params) {
    return axios.get(`${this.url}/appointments`, { params });
  }

  createAppointment(appointment) {
    return axios.post(`${this.url}/appointments`, appointment);
  }

  updateAppointment(id, appointment) {
    return axios.patch(`${this.url}/appointments/${id}`, appointment);
  }

  deleteAppointment(id) {
    return axios.delete(`${this.url}/appointments/${id}`);
  }

  googleConnection() {
    return axios.get(`${this.url}/google_connection`);
  }

  connectGoogle() {
    return axios.post(`${this.url}/google_connection`);
  }

  disconnectGoogle() {
    return axios.delete(`${this.url}/google_connection`);
  }
}

export default new AgendaAPI();
