# O caminho do formulário público do site até a ligação automática de demo.
# Diferente do `Voice::OutboundCallService` (chamado pelo painel, por um
# admin logado), aqui quem está do outro lado é um visitante anônimo — por
# isso as três checagens que o painel não precisa fazer: consentimento
# gravado, telefone em formato válido e o mesmo número não tendo recebido
# outra ligação recente. `VoiceCallRequest` fica gravado em qualquer
# desfecho, porque é também o registro de consentimento exigido para ligar
# com voz automatizada/IA — não só um log de erro.
class Voice::PublicCallRequestService
  # Defesa em profundidade: o Rack::Attack já limita por IP e pela string
  # crua do telefone antes da requisição chegar aqui. Este limite compara o
  # número já normalizado, então dois formatos diferentes do mesmo telefone
  # não escapam um do outro.
  REPEAT_CALL_WINDOW = 6.hours

  pattr_initialize [:name!, :email!, :phone_number!, :consent!, :ip_address!, { user_agent: nil }]

  def perform
    request = VoiceCallRequest.create!(
      account: route.account,
      twilio_voice_route: route,
      name: name,
      email: email,
      phone_number: phone_number,
      normalized_phone_number: normalized_phone,
      consent_given_at: consent ? Time.current : nil,
      ip_address: ip_address,
      user_agent: user_agent,
      status: 'pending'
    )

    reason = rejection_reason
    if reason
      request.update!(status: 'rejected', rejection_reason: reason)
      return request
    end

    dispatch(request)
  end

  private

  def rejection_reason
    return 'consent_not_given' unless consent
    return 'invalid_phone_number' if normalized_phone.blank?
    return 'recent_call_to_number' if called_recently?

    nil
  end

  def dispatch(request)
    call = Voice::OutboundCallService.new(
      route: route,
      to: normalized_phone,
      persona_slug: persona_slug
    ).perform
    request.update!(status: 'dispatched', call_sid: call.sid)
    request
  rescue Voice::OutboundCallService::Error => e
    request.update!(status: 'failed', rejection_reason: e.message)
    request
  end

  def called_recently?
    VoiceCallRequest.where(normalized_phone_number: normalized_phone, status: 'dispatched')
                     .where(created_at: REPEAT_CALL_WINDOW.ago..).exists?
  end

  # Mesma checagem do `Voice::OutboundCallService` — se passar aqui e falhar
  # lá, a causa é outra (número existe mas o Twilio recusa), não formato.
  def normalized_phone
    return @normalized_phone if defined?(@normalized_phone)

    limpo = phone_number.to_s.gsub(/[^\d+]/, '')
    @normalized_phone = limpo.start_with?('+') && limpo.length > 8 ? limpo : nil
  end

  # Configurado por fora, não pelo visitante: quem chama o formulário público
  # não escolhe de qual número ou com qual roteiro a ligação sai.
  def route
    @route ||= TwilioVoiceRoute.find_by!(phone_number: route_phone_number, enabled: true)
  end

  def route_phone_number
    ENV.fetch('PUBLIC_VOICE_DEMO_ROUTE_NUMBER')
  end

  def persona_slug
    ENV.fetch('PUBLIC_VOICE_DEMO_PERSONA_SLUG', 'nathan-demo-br')
  end
end
