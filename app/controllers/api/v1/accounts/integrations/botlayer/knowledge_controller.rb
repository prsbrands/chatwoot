class Api::V1::Accounts::Integrations::Botlayer::KnowledgeController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  def index
    render json: { docs: client.knowledge_docs }
  end

  def create
    doc = client.create_knowledge_doc(doc_params)
    client.set_doc_personas(doc['id'], persona_ids) unless doc_params[:is_global]
    render json: doc
  end

  def update
    doc = client.update_knowledge_doc(params[:id], doc_params.except(:slug))
    client.set_doc_personas(params[:id], doc_params[:is_global] ? [] : persona_ids)
    render json: doc
  end

  def destroy
    client.delete_knowledge_doc(params[:id])
    head :ok
  end

  private

  def doc_params
    params.permit(:slug, :title, :content, :locale, :is_global, :priority, :is_active)
  end

  def persona_ids
    params.permit(persona_ids: [])[:persona_ids] || []
  end
end
