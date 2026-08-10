# As falhas que o Twilio viu e nós não. Uma chamada que morre antes de alcançar
# o nosso webhook não deixa rastro em log nenhum daqui, e sem esta tela só se
# descobre entrando no console do Twilio — ou seja, quando alguém desconfia.
class Api::V1::Accounts::Integrations::Twilio::AlertsController < Api::V1::Accounts::Integrations::Twilio::BaseController
  def index
    return render json: { alerts: [] } if credential.blank?

    render json: { alerts: client.recent_alerts }
  end
end
