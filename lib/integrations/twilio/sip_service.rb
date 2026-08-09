# Domínio SIP e credenciais dos softphones, no Twilio.
#
# Só enxergamos e alteramos o domínio que nós mesmos criamos: a conta do cliente
# pode ter domínios servindo outros sistemas, e reapontar um deles derrubaria a
# telefonia de terceiros. Os outros são listados como externos, sem edição.
class Integrations::Twilio::SipService
  class ApiError < StandardError; end

  MANAGED_NAME = 'CortexGen Chat'.freeze

  pattr_initialize [:credential!]

  def domains
    client.api.account.sip.domains.list.map do |domain|
      {
        sid: domain.sid,
        domain_name: domain.domain_name,
        friendly_name: domain.friendly_name,
        voice_url: domain.voice_url,
        managed: domain.friendly_name == MANAGED_NAME
      }
    end
  rescue ::Twilio::REST::RestError => e
    raise ApiError, e.message
  end

  # `domain_name` precisa ser único no Twilio inteiro, não só na conta — o erro
  # de nome tomado vem da API e é repassado como está.
  def create_domain(subdomain)
    domain = client.api.account.sip.domains.create(
      domain_name: "#{subdomain}.sip.twilio.com",
      friendly_name: MANAGED_NAME,
      sip_registration: true
    )
    # A lista leva o nome do domínio para ser reencontrada sem ambiguidade
    # depois — o SID do mapeamento não é o SID da lista.
    list = client.api.account.sip.credential_lists.create(friendly_name: domain.domain_name)
    map_credential_list(domain.sid, list.sid)
    { sid: domain.sid, domain_name: domain.domain_name }
  rescue ::Twilio::REST::RestError => e
    raise ApiError, e.message
  end

  def credentials(domain_sid)
    list_sid = credential_list_sid!(domain_sid)
    client.api.account.sip.credential_lists(list_sid).credentials.list.map do |credential|
      { sid: credential.sid, username: credential.username }
    end
  rescue ::Twilio::REST::RestError => e
    raise ApiError, e.message
  end

  # A senha é devolvida uma única vez, para o agente colar no softphone. Não a
  # guardamos: quem a conhece é o Twilio, e perdê-la significa gerar outra.
  def create_credential(domain_sid, username)
    list_sid = credential_list_sid!(domain_sid)
    password = SecureRandom.alphanumeric(24)
    client.api.account.sip.credential_lists(list_sid).credentials.create(username: username, password: password)
    { username: username, password: password }
  rescue ::Twilio::REST::RestError => e
    raise ApiError, e.message
  end

  def delete_credential(domain_sid, credential_sid)
    client.api.account.sip.credential_lists(credential_list_sid!(domain_sid)).credentials(credential_sid).delete
  rescue ::Twilio::REST::RestError => e
    raise ApiError, e.message
  end

  private

  # O registro do softphone e as chamadas usam mapeamentos separados; sem os
  # dois, o Zoiper conecta mas a chamada não completa.
  def map_credential_list(domain_sid, list_sid)
    domain = client.api.account.sip.domains(domain_sid)
    domain.auth.registrations.credential_list_mappings.create(credential_list_sid: list_sid)
    domain.auth.calls.credential_list_mappings.create(credential_list_sid: list_sid)
  end

  def credential_list_sid!(domain_sid)
    domain_name = client.api.account.sip.domains(domain_sid).fetch.domain_name
    list = client.api.account.sip.credential_lists.list.find { |candidate| candidate.friendly_name == domain_name }
    raise ApiError, "No credential list found for #{domain_name}" if list.blank?

    list.sid
  end

  def client
    @client ||= ::Twilio::REST::Client.new(credential.account_sid, credential.auth_token)
  end
end
