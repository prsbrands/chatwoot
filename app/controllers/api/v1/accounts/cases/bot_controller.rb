# O que o n8n usa dos casos, com o token de usuário da conta (o mesmo do nó
# Historico): o MontaPrompt lê o contexto, abre o caso e repassa a resposta do
# cliente; o workflow "CortexGen Caso" reserva e conclui os repasses da equipe.
# Conta sem a flag `cases`: 401, e o bot segue sem casos.
class Api::V1::Accounts::Cases::BotController < Api::V1::Accounts::Cases::BaseController
  MAX_CLAIMS = 10

  before_action -> { authorize ::Cases::Case, :bot? }
  before_action :fetch_conversation, only: [:context, :open, :customer_replied]

  def context
    render json: service.context(@conversation)
  end

  def open
    render json: service.open!(@conversation, type_id: params.require(:type_id), title: params.require(:title),
                                              description: params.require(:description), language: params[:language])
  end

  def customer_replied
    render json: { payload: service.customer_replied!(@conversation, params.require(:body)) }
  end

  def claim_relays
    inbox_ids = Array(params.require(:inbox_ids)).map(&:to_i)
    render json: { payload: service.claim_relays(inbox_ids, params.fetch(:limit, 5).to_i.clamp(1, MAX_CLAIMS)) }
  end

  def relay_result
    event = service.relay_result!(params[:id], sent: ActiveModel::Type::Boolean.new.cast(params.require(:sent)), message: params[:message])
    render json: { id: event.id, relay: event.metadata['relay'] }
  end

  private

  def service
    ::Cases::AiCases.new(Current.account)
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
  end
end
