# O que o workflow "CortexGen Evolução" usa, com o token de usuário da conta:
# reservar as conversas com sinal e gravar o que o LLM propôs
# (AiEvolution::Bot). Conta sem a flag `ai_evolution`: 401, e fica de fora.
class Api::V1::Accounts::AiEvolution::BotController < Api::V1::Accounts::AiEvolution::BaseController
  MAX_CLAIMS = 20

  before_action -> { authorize ::AiEvolution::Suggestion, :bot? }

  def claims
    routes = Array(params.require(:routes)).map { |route| route.permit(:inbox_id, :persona_id).to_h.symbolize_keys }
    limit = params.fetch(:limit, 10).to_i.clamp(1, MAX_CLAIMS)
    render json: { payload: ::AiEvolution::Bot.new(Current.account).claim(routes, limit) }
  end

  def results
    saved = ::AiEvolution::Bot.new(Current.account).record!(result_params)
    render json: { saved: saved.map(&:id) }
  end

  private

  def result_params
    permitted = params.permit(:conversation_id, :last_message_id, :persona_id, :persona_name,
                              suggestions: [:kind, :title, :content, :target_doc_id, :replace_text, :same_as, :rationale,
                                            :customer_quote, :team_quote])
    raise ActionController::ParameterMissing, :conversation_id if permitted[:conversation_id].blank?
    raise ActionController::ParameterMissing, :persona_id if permitted[:persona_id].blank?

    permitted.to_h.deep_symbolize_keys
  end
end
