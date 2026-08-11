# O bot ligando, em vez de atendendo.
#
# Todo o resto da chamada é o mesmo caminho de sempre: o Twilio busca o TwiML em
# `/twilio/voice/outgoing`, que devolve o `<Connect><Stream>` para o serviço de
# mídia. O que muda é quem inicia e qual roteiro o bot usa.
class Voice::OutboundCallService
  class Error < StandardError; end

  pattr_initialize [:route!, :to!, { persona_slug: nil }]

  def perform
    numero = normalized_to
    raise Error, "#{to} não parece um número em formato internacional (+código país)" if numero.blank?

    call = client.calls.create(to: numero, from: route.phone_number, url: twiml_url)
    record(call, numero)
    call
  rescue ::Twilio::REST::RestError => e
    # A mensagem do Twilio é específica ("unverified", "not permitted"); o
    # código é o que se cola na busca da documentação deles.
    raise Error, [e.message, ("Twilio code #{e.code}" if e.code)].compact.join(' — ')
  end

  private

  # Sem E.164 o Twilio recusa, e a mensagem de erro dele não diz que o problema
  # é o formato. Só normaliza o que já vem com país; adivinhar DDI a partir do
  # número da conta erraria justamente em quem liga de fora.
  def normalized_to
    limpo = to.to_s.gsub(/[^\d+]/, '')
    limpo.start_with?('+') && limpo.length > 8 ? limpo : nil
  end

  # A chamada nasce registrada. Sem isto ela só apareceria no relatório ao
  # desligar, e uma que nunca é atendida não apareceria nunca.
  def record(call, numero)
    TwilioVoiceCall.create!(
      account: route.account,
      call_sid: call.sid,
      phone_number: route.phone_number,
      from_number: numero,
      status: call.status
    )
  end

  def twiml_url
    Rails.application.routes.url_helpers.twilio_voice_outgoing_url(
      host: ENV.fetch('FRONTEND_URL', nil),
      persona_slug: persona_slug.presence
    )
  end

  def client
    credential = route.account.twilio_credential
    raise Error, 'esta conta não tem credencial do Twilio' if credential.blank?

    ::Twilio::REST::Client.new(credential.account_sid, credential.auth_token)
  end
end
