# Tela Uso de IA: o gasto da conta com LLM (bot_interactions) e com o Jev num
# intervalo, e o teto mensal, que só o Super Admin muda (SuperAdmin::AiBudgetsController).
class Api::V1::Accounts::Integrations::Botlayer::AiUsageController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  MAX_RANGE = 93.days

  def show
    render json: client.ai_usage(Current.account.id, range_from, range_to)
  end

  private

  def range_from
    @range_from ||= params[:from].present? ? time_param(:from) : Time.current.beginning_of_month
  end

  def range_to
    to = params[:to].present? ? time_param(:to) : Time.current
    [to, range_from + MAX_RANGE].min
  end

  def time_param(key)
    Time.zone.iso8601(params[key])
  rescue ArgumentError
    raise ActionController::BadRequest, "invalid #{key}"
  end
end
