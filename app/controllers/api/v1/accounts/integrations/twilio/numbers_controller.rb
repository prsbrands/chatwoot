class Api::V1::Accounts::Integrations::Twilio::NumbersController < Api::V1::Accounts::Integrations::Twilio::BaseController
  before_action :ensure_connected

  # Devolve os números com as capabilities do Twilio e com a inbox já ligada a
  # cada um, para a tela mostrar o que dá para fazer antes de o cliente tentar.
  def index
    page = client.phone_numbers(search: params[:search], page_url: params[:page_url])
    numbers = page[:numbers].map do |number|
      number.merge(
        inbox: inbox_for(number[:phone_number]),
        voice_inbox: voice_inbox_for(number[:phone_number])
      )
    end
    render json: { numbers: numbers, next_page_url: page[:next_page_url], sms_webhook_url: sms_webhook_url }
  end

  # Provisiona a inbox de SMS do número e aponta o webhook no próprio Twilio.
  def create
    inbox = Integrations::Twilio::ProvisionSmsService.new(
      account: Current.account,
      credential: credential,
      phone_number: params[:phone_number],
      name: params[:name]
    ).perform
    render json: { inbox: { id: inbox.id, name: inbox.name } }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
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

  # A rota de voz cria a própria inbox (`Voz — <número>`) na primeira chamada,
  # separada da inbox de SMS do mesmo número — ver `Voice::CallReportService`.
  # Sem isso, a tela de números não sabia nada sobre voz e marcava como
  # "Not connected yet" um número que só faz chamada, nunca SMS.
  def voice_inbox_for(phone_number)
    route = voice_routes[phone_number]
    return if route.blank? || route.voice_inbox_id.blank?

    inbox = Current.account.inboxes.find_by(id: route.voice_inbox_id)
    return if inbox.blank?

    { id: inbox.id, name: inbox.name }
  end

  def voice_routes
    @voice_routes ||= Current.account.twilio_voice_routes.index_by(&:phone_number)
  end

  # O endpoint de entrada de SMS é único da instalação: o Chatwoot resolve o
  # canal pelo número de destino do payload.
  def sms_webhook_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/twilio/callback"
  end
end
