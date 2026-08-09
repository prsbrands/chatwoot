# Endpoints que o Twilio chama durante uma chamada de voz. São públicos, então
# cada requisição é verificada pela assinatura HMAC do Twilio antes de virar
# TwiML — sem isso, qualquer um poderia fazer a instância discar.
#
# Nada aqui toca `enterprise/`: o canal de voz da Chatwoot é da licença
# comercial e as rotas dele nem existem nesta edição.
class Twilio::VoiceRoutingController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_route
  before_action :verify_twilio_signature

  # Chamada entrando: toca no destino humano com um limite de tempo. O que fazer
  # quando ninguém atende é decidido em `dial_status`, para onde o próprio Twilio
  # nos traz de volta.
  def incoming
    record_call
    response = ::Twilio::TwiML::VoiceResponse.new
    response.dial(timeout: @route.ring_timeout, action: dial_status_url, method: 'POST') do |dial|
      @route.sip? ? dial.sip("sip:#{@route.destination}") : dial.number(@route.destination)
    end
    render xml: response.to_s
  end

  # `DialCallStatus` é 'completed' quando a conversa aconteceu; qualquer outro
  # valor (no-answer, busy, failed) significa que ninguém atendeu.
  def dial_status
    status = params[:DialCallStatus]
    update_call_status(status)

    response = ::Twilio::TwiML::VoiceResponse.new
    if status != 'completed'
      response.say(message: I18n.t('twilio.voice.no_answer'), language: 'en-US')
      response.hangup
    end
    render xml: response.to_s
  end

  private

  def set_route
    @route = TwilioVoiceRoute.find_by(phone_number: params[:To].presence || params[:Called], enabled: true)
    head :not_found if @route.blank?
  end

  def verify_twilio_signature
    validator = ::Twilio::Security::RequestValidator.new(@route.account.twilio_credential.auth_token)
    return if validator.validate(request.original_url, request.request_parameters, request.headers['X-Twilio-Signature'].to_s)

    Rails.logger.warn("TWILIO_VOICE_BAD_SIGNATURE number=#{@route.phone_number}")
    head :forbidden
  end

  def record_call
    TwilioVoiceCall.create!(
      account: @route.account,
      call_sid: params[:CallSid],
      phone_number: @route.phone_number,
      from_number: params[:From]
    )
  end

  def update_call_status(status)
    TwilioVoiceCall.find_by(call_sid: params[:CallSid])&.update(status: status)
  end

  def dial_status_url
    twilio_voice_dial_status_url(host: ENV.fetch('FRONTEND_URL', nil))
  end
end
