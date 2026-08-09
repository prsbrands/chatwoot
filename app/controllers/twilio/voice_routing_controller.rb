# Endpoints que o Twilio chama durante uma chamada de voz. São públicos, então
# cada requisição é verificada pela assinatura HMAC do Twilio antes de virar
# TwiML — sem isso, qualquer um poderia fazer a instância discar.
#
# Nada aqui toca `enterprise/`: o canal de voz da Chatwoot é da licença
# comercial e as rotas dele nem existem nesta edição.
class Twilio::VoiceRoutingController < ApplicationController
  before_action :set_route
  before_action :verify_twilio_signature

  # Chamada entrando: ou o bot atende direto, ou toca no destino humano com um
  # limite de tempo. O que fazer quando ninguém atende é decidido em
  # `dial_status`, para onde o próprio Twilio nos traz de volta.
  def incoming
    record_call
    return render xml: connect_to_bot.to_s if @route.bot_answers_first?

    response = ::Twilio::TwiML::VoiceResponse.new
    response.dial(timeout: @route.ring_timeout, action: dial_status_url, method: 'POST') do |dial|
      @route.sip? ? dial.sip("sip:#{@route.destination}") : dial.number(@route.destination)
    end
    render xml: response.to_s
  end

  # `DialCallStatus` é 'completed' quando a conversa aconteceu; qualquer outro
  # valor (no-answer, busy, failed) significa que ninguém atendeu — e é aí que o
  # transbordo para o bot acontece.
  def dial_status
    status = params[:DialCallStatus]
    update_call_status(status)
    return render xml: ::Twilio::TwiML::VoiceResponse.new.to_s if status == 'completed'
    return render xml: connect_to_bot.to_s if @route.bot_on_no_answer?

    response = ::Twilio::TwiML::VoiceResponse.new
    response.say(message: I18n.t('twilio.voice.no_answer'), language: 'en-US')
    response.hangup
    render xml: response.to_s
  end

  private

  # `<Connect><Stream>` entrega o áudio dos dois lados ao serviço de mídia e
  # mantém a chamada de pé enquanto o WebSocket viver. Os parâmetros são o que o
  # serviço recebe no evento `start` — sem eles ele saberia o `CallSid` mas não
  # qual número foi discado, que é a chave da configuração.
  def connect_to_bot
    ::Twilio::TwiML::VoiceResponse.new do |response|
      response.connect do |connect|
        connect.stream(url: stream_url) do |stream|
          stream.parameter(name: 'call_sid', value: params[:CallSid])
          stream.parameter(name: 'phone_number', value: @route.phone_number)
          stream.parameter(name: 'from_number', value: params[:From].to_s)
        end
      end
    end
  end

  def stream_url
    GlobalConfigService.load('VOICE_STREAM_URL', nil).presence ||
      raise(StandardError, 'VOICE_STREAM_URL is not set — Super Admin → Settings → Voice Agent')
  end

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
