# Fatos da memória pela tela. Fato escrito ou corrigido por uma pessoa vira
# manual: a IA não muda nem apaga mais.
class Api::V1::Accounts::AiMemory::FactsController < Api::V1::Accounts::BaseController
  before_action :fetch_fact, only: [:update, :destroy]
  before_action -> { authorize ::AiMemory::Fact, :"#{params[:action]}?" }

  def create
    contact = Current.account.contacts.find(params.require(:contact_id))
    fact = ::AiMemory::Fact.create!(contact: contact, account: Current.account, body: params.require(:body),
                                    source: :manual, pinned: ActiveModel::Type::Boolean.new.cast(params[:pinned]) || false,
                                    created_by: Current.user)
    render json: fact.as_api_json
  end

  def update
    @fact.pinned = ActiveModel::Type::Boolean.new.cast(params[:pinned]) if params.key?(:pinned)
    if params.key?(:body) && params[:body].to_s.squish != @fact.body
      @fact.assign_attributes(body: params[:body], source: :manual, created_by: Current.user)
    end
    @fact.save!
    render json: @fact.as_api_json
  end

  def destroy
    @fact.destroy!
    head :ok
  end

  private

  def fetch_fact
    @fact = ::AiMemory::Fact.where(account: Current.account).find(params[:id])
  end
end
