/* global axios */
import ApiClient from './ApiClient';

// Comercial: catálogo (itens e categorias), dados da empresa, formas de
// pagamento, provedores de cobrança online, orçamentos, faturas, recibos e
// assinaturas.
// Imagens e logo sobem pelo /upload e chegam aqui como blob_id.
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

  paymentProviders() {
    return axios.get(`${this.url}/payment_providers`);
  }

  createPaymentProvider(provider) {
    return axios.post(`${this.url}/payment_providers`, provider);
  }

  updatePaymentProvider(id, provider) {
    return axios.patch(`${this.url}/payment_providers/${id}`, provider);
  }

  documents(params) {
    return axios.get(`${this.url}/documents`, { params });
  }

  reviewCount() {
    return axios.get(`${this.url}/documents/review_count`);
  }

  document(id) {
    return axios.get(`${this.url}/documents/${id}`);
  }

  createDocument(document) {
    return axios.post(`${this.url}/documents`, document);
  }

  updateDocument(id, document) {
    return axios.patch(`${this.url}/documents/${id}`, document);
  }

  deleteDocument(id) {
    return axios.delete(`${this.url}/documents/${id}`);
  }

  // action: pdf | accept | decline | void | to_invoice
  documentAction(id, action) {
    return axios.post(`${this.url}/documents/${id}/${action}`);
  }

  deliverDocument(id, delivery) {
    return axios.post(`${this.url}/documents/${id}/deliver`, delivery);
  }

  addDocumentPayment(id, payment) {
    return axios.post(`${this.url}/documents/${id}/payments`, payment);
  }

  removeDocumentPayment(id, paymentId) {
    return axios.delete(`${this.url}/documents/${id}/payments/${paymentId}`);
  }

  issueReceipt(id, paymentId) {
    return axios.post(
      `${this.url}/documents/${id}/payments/${paymentId}/receipt`
    );
  }

  subscriptions(params) {
    return axios.get(`${this.url}/subscriptions`, { params });
  }

  subscription(id) {
    return axios.get(`${this.url}/subscriptions/${id}`);
  }

  createSubscription(subscription) {
    return axios.post(`${this.url}/subscriptions`, subscription);
  }

  deliverSubscription(id, delivery) {
    return axios.post(`${this.url}/subscriptions/${id}/deliver`, delivery);
  }

  cancelSubscription(id, atPeriodEnd) {
    return axios.post(`${this.url}/subscriptions/${id}/cancel`, {
      at_period_end: atPeriodEnd,
    });
  }

  profile() {
    return axios.get(`${this.url}/profile`);
  }

  updateProfile(profile) {
    return axios.patch(`${this.url}/profile`, profile);
  }
}

export default new CommerceAPI();
