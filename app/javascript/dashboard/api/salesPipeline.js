/* global axios */
import ApiClient from './ApiClient';

// Funil de vendas (flag sales_pipeline): um funil por conta, com etapas e
// negocios. O backend cria o funil padrao na primeira leitura.
class SalesPipelineAPI extends ApiClient {
  constructor() {
    super('sales', { accountScoped: true });
  }

  pipelines() {
    return axios.get(`${this.url}/pipelines`);
  }

  createStage(pipelineId, stage) {
    return axios.post(`${this.url}/pipelines/${pipelineId}/stages`, stage);
  }

  updateStage(pipelineId, stageId, stage) {
    return axios.patch(
      `${this.url}/pipelines/${pipelineId}/stages/${stageId}`,
      stage
    );
  }

  deleteStage(pipelineId, stageId) {
    return axios.delete(`${this.url}/pipelines/${pipelineId}/stages/${stageId}`);
  }

  deals(params = {}) {
    return axios.get(`${this.url}/deals`, { params });
  }

  deal(id) {
    return axios.get(`${this.url}/deals/${id}`);
  }

  createDeal(deal) {
    return axios.post(`${this.url}/deals`, deal);
  }

  updateDeal(id, deal) {
    return axios.patch(`${this.url}/deals/${id}`, deal);
  }

  deleteDeal(id) {
    return axios.delete(`${this.url}/deals/${id}`);
  }
}

export default new SalesPipelineAPI();
