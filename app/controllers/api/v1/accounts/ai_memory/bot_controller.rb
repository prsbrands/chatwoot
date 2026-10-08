# O que o n8n usa para a memória do cliente, com o token de usuário da conta (o
# mesmo do nó Historico): o MontaPrompt lê a memória do contato da conversa; o
# workflow "CortexGen Memória" reserva as conversas paradas e grava o que o LLM
# tirou delas.
class Api::V1::Accounts::AiMemory::BotController < Api::V1::Accounts::BaseController
  MAX_CLAIMS = 10

  before_action -> { authorize ::AiMemory::Fact, :bot? }

  def contact
    conversation = Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
    render json: ::AiMemory::Bot.new(Current.account).for_conversation(conversation)
  end

  def claims
    inbox_ids = Array(params.require(:inbox_ids)).map(&:to_i)
    limit = params.fetch(:limit, 5).to_i.clamp(1, MAX_CLAIMS)
    render json: { payload: ::AiMemory::Bot.new(Current.account).claim(inbox_ids, limit) }
  end

  def update
    summary = ::AiMemory::Bot.new(Current.account).apply!(update_params)
    render json: { contact_id: summary.contact_id, last_message_id: summary.last_message_id, refreshed_at: summary.refreshed_at }
  end

  private

  def update_params
    permitted = params.permit(:contact_id, :conversation_id, :last_message_id, :summary, add: [], remove: [], update: [:id, :text])
    raise ActionController::ParameterMissing, :contact_id if permitted[:contact_id].blank?
    raise ActionController::ParameterMissing, :last_message_id if permitted[:last_message_id].blank?

    {
      contact_id: permitted[:contact_id], conversation_id: permitted[:conversation_id],
      last_message_id: permitted[:last_message_id], summary: permitted[:summary].to_s,
      add: permitted[:add] || [], remove: permitted[:remove] || [], update: permitted[:update] || []
    }
  end
end
