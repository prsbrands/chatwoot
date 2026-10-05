/* global axios */
import ApiClient from './ApiClient';

// Comercial: catálogo (itens e categorias), dados da empresa e formas de
// pagamento. Imagens e logo sobem pelo /upload e chegam aqui como blob_id.
class CommerceAPI extends ApiClient {
  constructor() {
    super('commerce', { accountScoped: true });
  }

  items(params) {
    return axios.get(`${this.url}/items`, { params });
  }

  createItem(item) {
    return axios.post(`${this.url}/items`, item);
  }

  updateItem(id, item) {
    return axios.patch(`${this.url}/items/${id}`, item);
  }

  deleteItem(id) {
    return axios.delete(`${this.url}/items/${id}`);
  }

  addItemImage(id, blobId) {
    return axios.post(`${this.url}/items/${id}/images`, { blob_id: blobId });
  }

  removeItemImage(id, attachmentId) {
    return axios.delete(`${this.url}/items/${id}/images/${attachmentId}`);
  }

  categories() {
    return axios.get(`${this.url}/categories`);
  }

  createCategory(category) {
    return axios.post(`${this.url}/categories`, category);
  }

  updateCategory(id, category) {
    return axios.patch(`${this.url}/categories/${id}`, category);
  }

  deleteCategory(id) {
    return axios.delete(`${this.url}/categories/${id}`);
  }

  paymentMethods() {
    return axios.get(`${this.url}/payment_methods`);
  }

  createPaymentMethod(method) {
    return axios.post(`${this.url}/payment_methods`, method);
  }

  updatePaymentMethod(id, method) {
    return axios.patch(`${this.url}/payment_methods/${id}`, method);
  }

  deletePaymentMethod(id) {
    return axios.delete(`${this.url}/payment_methods/${id}`);
  }

  profile() {
    return axios.get(`${this.url}/profile`);
  }

  updateProfile(profile) {
    return axios.patch(`${this.url}/profile`, profile);
  }
}

export default new CommerceAPI();
