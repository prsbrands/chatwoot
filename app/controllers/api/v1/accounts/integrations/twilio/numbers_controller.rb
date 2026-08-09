class Api::V1::Accounts::Integrations::Twilio::NumbersController < Api::V1::Accounts::Integrations::Twilio::BaseController
  before_action :ensure_connected

  # Devolve os números com as capabilities do Twilio e com a inbox já ligada a
  # cada um, para a tela mostrar o que dá para fazer antes de o cliente tentar.
  def index
    numbers = client.phone_numbers.map { |number| number.merge(inbox: inbox_for(number[:phone_number])) }
    render json: { numbers: numbers, sms_webhook_url: sms_webhook_url }
  end

  private

  def ensure_connected
    render json: { error: I18n.t('errors.twilio.not_connected') }, status: :unprocessable_entity if credential.blank?
  end

  def inbox_for(phone_number)
    channel = twilio_channels[phone_number]
    return if channel.blank?

    { id: channel.inbox.id, name: channel.inbox.name }
  end

  def twilio_channels
    @twilio_channels ||= Current.account.twilio_sms.includes(:inbox).index_by(&:phone_number)
  end

  # O endpoint de entrada de SMS é único da instalação: o Chatwoot resolve o
  # canal pelo número de destino do payload.
  def sms_webhook_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/twilio/callback"
  end
end
