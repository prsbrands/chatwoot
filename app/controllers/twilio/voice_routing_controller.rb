# Endpoints que o Twilio chama durante uma chamada de voz. São públicos, então
# cada requisição é verificada pela assinatura HMAC do Twilio antes de virar
# TwiML — sem isso, qualquer um poderia fazer a instância discar.
#
# Nada aqui toca `enterprise/`: o canal de voz da Chatwoot é da licença
# comercial e as rotas dele nem existem nesta edição.
class Twilio::VoiceRoutingController < ApplicationController
  # O que o Twilio chama de "não é gente" na detecção de secretária eletrônica.
  MACHINE_ANSWERS = %w[machine_start machine_end_beep machine_end_silence machine_end_other fax].freeze

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

  # Chamada saindo: o bot liga para alguém, em vez de atender.
  #
  # Precisa de endpoint próprio por causa de uma inversão que quebraria em
  # silêncio: numa chamada de saída o `To` é a pessoa e o `From` é o nosso
  # número, então o `set_route` normal procuraria rota para o número do
  # prospecto e devolveria 404. Por isso `set_route` olha o `From` aqui.
  #
  # A persona também é outra. O roteiro da rota é de quem atende — abre com
  # "obrigado por ligar" e faz triagem de fornecedor. Quem liga precisa se
  # apresentar e dizer por que ligou, então quem dispara escolhe a persona e ela
  # viaja como parâmetro do stream.
  def outgoing
    render xml: connect_to_bot(other_party: params[:To].to_s, persona_slug: params[:persona_slug]).to_s
  end

  # Caiu no correio de voz. O Twilio trata "atendido pela secretária" como
  # chamada atendida, conecta o `<Stream>` e o bot conversa com a gravação até
  # alguém desligar: duas chamadas em 11/08 gastaram 305 s negociando com o menu
  # da operadora, e o modelo chegou a dizer "parece que está escuchando un
  # mensaje automático" antes de seguir perguntando.
  #
  # A detecção é assíncrona de propósito: no modo síncrono o Twilio só pede o
  # TwiML depois de decidir, e quem atende de verdade ouviria alguns segundos de
  # silêncio a mais em toda chamada — caro num projeto cujo gargalo é latência.
  # Aqui a chamada começa na hora e este webhook a derruba depois, se for máquina.
  #
  # `unknown` não derruba: o Twilio não decidiu, e desligar na cara de um humano
  # é pior do que pagar por uma secretária ocasional.
  def amd_status
    answered_by = params[:AnsweredBy]
    return head :ok unless MACHINE_ANSWERS.include?(answered_by)

    Rails.logger.info("TWILIO_VOICE_AMD_HANGUP sid=#{params[:CallSid]} answered_by=#{answered_by}")
    update_call_status(answered_by)
    hang_up_call
    head :ok
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
  # `other_party` é quem está do outro lado da linha: quem ligou, numa chamada
  # entrando; quem foi chamado, numa saindo. É o número que vira contato no CRM.
  def connect_to_bot(other_party: nil, persona_slug: nil)
    ::Twilio::TwiML::VoiceResponse.new do |response|
      response.connect do |connect|
        connect.stream(url: stream_url) do |stream|
          stream.parameter(name: 'call_sid', value: params[:CallSid])
          stream.parameter(name: 'phone_number', value: @route.phone_number)
          stream.parameter(name: 'from_number', value: other_party.presence || params[:From].to_s)
          stream.parameter(name: 'persona_slug', value: persona_slug) if persona_slug.present?
        end
      end
    end
  end

  def stream_url
    GlobalConfigService.load('VOICE_STREAM_URL', nil).presence ||
      raise(StandardError, 'VOICE_STREAM_URL is not set — Super Admin → Settings → Voice Agent')
  end

  # Encerrar a chamada pelo nosso lado. O `<Stream>` cai junto quando o Twilio
  # completa a chamada, então o serviço de mídia fecha sozinho e grava o
  # relatório — não é preciso avisá-lo.
  def hang_up_call
    credential = @route.account.twilio_credential
    client = ::Twilio::REST::Client.new(credential.account_sid, credential.auth_token)
    client.calls(params[:CallSid]).update(status: 'completed')
  end

  # Numa chamada entrando, o nosso número é o destino; numa saindo, é a origem.
  def set_route
    return set_route_from_call if action_name == 'amd_status'

    nosso_numero = action_name == 'outgoing' ? params[:From] : (params[:To].presence || params[:Called])
    @route = TwilioVoiceRoute.find_by(phone_number: nosso_numero, enabled: true)
    head :not_found if @route.blank?
  end

  # O webhook do AMD chega com quatro campos e **nenhum telefone**:
  # `CallSid`, `AnsweredBy`, `MachineDetectionDuration` e `AccountSid`. Resolver
  # pelo `From` como o `outgoing` devolve 404 — foi assim que a primeira versão
  # deixou uma chamada seguir para o correio de voz sem que nada no log gritasse
  # além de um "Filter chain halted". A rota sai da chamada já gravada.
  def set_route_from_call
    call = TwilioVoiceCall.find_by(call_sid: params[:CallSid])
    @route = call && TwilioVoiceRoute.find_by(phone_number: call.phone_number, enabled: true)
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
