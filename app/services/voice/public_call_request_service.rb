# O caminho do formulário público do site até a ligação automática de demo.
# Diferente do `Voice::OutboundCallService` (chamado pelo painel, por um
# admin logado), aqui quem está do outro lado é um visitante anônimo — por
# isso as quatro checagens que o painel não precisa fazer: consentimento
# gravado, telefone em formato válido, DDI com rota de demo configurada e o
# mesmo número não tendo recebido outra ligação recente. `VoiceCallRequest`
# fica gravado em qualquer desfecho, porque é também o registro de
# consentimento exigido para ligar com voz automatizada/IA — não só um log
# de erro.
class Voice::PublicCallRequestService
  # Defesa em profundidade: o Rack::Attack já limita por IP e pela string
  # crua do telefone antes da requisição chegar aqui. Este limite compara o
  # número já normalizado, então dois formatos diferentes do mesmo telefone
  # não escapam um do outro.
  REPEAT_CALL_WINDOW = 6.hours

  pattr_initialize [:name!, :email!, :phone_number!, :consent!, :ip_address!, { user_agent: nil }]

  def perform
    request = VoiceCallRequest.create!(
      account: account,
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
    return 'country_not_supported' if route.nil?
    return 'recent_call_to_number' if called_recently?

    nil
  end

  def dispatch(request)
    call = Voice::OutboundCallService.new(
      route: route,
      to: normalized_phone,
      persona_slug: route.public_demo_persona_slug
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

  # A rota é escolhida pelo DDI do número discado, não pelo visitante — é o
  # que faz a demo ligar do número panamenho pra quem está no Panamá, do
  # brasileiro pra quem está no Brasil, e por aí vai (mesma razão que já
  # fazia o outbound existente preferir o +5078389480 ao +16893539100 pra
  # prospecto panamenho: identificador de chamada nacional responde mais).
  # Do mais longo pro mais curto, pra um DDI de 1 dígito não casar por
  # engano dentro do prefixo de um de 2 ou 3.
  def route
    return @route if defined?(@route)
    return @route = nil if normalized_phone.blank?

    digits = normalized_phone.delete('+')
    code = configured_dial_codes.find { |dial_code| digits.start_with?(dial_code) }
    @route = code && TwilioVoiceRoute.find_by(public_demo_dial_code: code, enabled: true)
  end

  def configured_dial_codes
    TwilioVoiceRoute.where.not(public_demo_dial_code: nil)
                     .order(Arel.sql('length(public_demo_dial_code) DESC'))
                     .pluck(:public_demo_dial_code)
  end

  # Não vem de nenhuma rota específica — é preciso ter uma conta pra gravar
  # até o pedido que não bateu com DDI nenhum. Toda rota com demo configurada
  # pertence à mesma conta hoje; se um dia isso deixar de ser verdade, o
  # `first!` falha alto em vez de atribuir o pedido à conta errada.
  def account
    @account ||= Account.joins(:twilio_voice_routes)
                         .where.not(twilio_voice_routes: { public_demo_dial_code: nil })
                         .first!
  end
end
