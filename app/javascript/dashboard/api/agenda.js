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

  eventTypes() {
    return axios.get(`${this.url}/event_types`);
  }

  createEventType(eventType) {
    return axios.post(`${this.url}/event_types`, eventType);
  }

  updateEventType(id, eventType) {
    return axios.patch(`${this.url}/event_types/${id}`, eventType);
  }

  deleteEventType(id) {
    return axios.delete(`${this.url}/event_types/${id}`);
  }

  availabilities() {
    return axios.get(`${this.url}/availabilities`);
  }

  updateAvailability(userId, availability) {
    return axios.put(`${this.url}/availabilities/${userId}`, availability);
  }

  freeSlots(params) {
    return axios.get(`${this.url}/free_slots`, { params });
  }
}

export default new AgendaAPI();
