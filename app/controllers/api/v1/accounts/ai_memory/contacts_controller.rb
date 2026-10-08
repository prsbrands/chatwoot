# A memória de um contato na tela: o resumo (editável) e os fatos.
class Api::V1::Accounts::AiMemory::ContactsController < Api::V1::Accounts::BaseController
  before_action :fetch_contact
  before_action -> { authorize ::AiMemory::Fact, params[:action] == 'show' ? :show? : :update? }

  def show
    render json: memory_json
  end

  def update
    summary = ::AiMemory::Summary.find_or_initialize_by(contact: @contact)
    summary.update!(account: Current.account, body: params.require(:summary).to_s)
    render json: memory_json
  end

  private

  def fetch_contact
    @contact = Current.account.contacts.find(params[:id])
  end

  def memory_json
    summary = ::AiMemory::Summary.find_by(contact: @contact)
    {
      contact_id: @contact.id,
      summary: summary&.body.to_s,
      refreshed_at: summary&.refreshed_at,
      summary_updated_at: summary&.updated_at,
      facts: ::AiMemory::Fact.where(contact: @contact).ordered.map(&:as_api_json)
    }
  end
end
