# Lê a conta Twilio do cliente: valida as credenciais e lista os números com o
# que cada um sabe fazer. Quem envia e recebe mensagem é o Channel::TwilioSms —
# aqui só descobrimos o que existe antes de provisionar.
class Integrations::Twilio::AccountClient
  class ApiError < StandardError; end

  PAGE_SIZE = 25

  pattr_initialize [:credential!]

  # O nome da conta no Twilio serve de confirmação visual de que a chave é da
  # conta certa — Account SID sozinho não diz nada para o usuário.
  def friendly_name
    client.api.accounts(credential.account_sid).fetch.friendly_name
  rescue ::Twilio::REST::RestError => e
    raise ApiError, twilio_message(e)
  end

  # Uma página por vez: `list` pagina sozinho e traz a conta inteira, o que numa
  # conta grande vira muitas chamadas ao Twilio a cada abertura da tela. A busca
  # é feita pelo próprio Twilio (`phone_number` casa por trecho), não em memória.
  def phone_numbers(search: nil, page_url: nil)
    page = page_url.present? ? client.incoming_phone_numbers.get_page(page_url) : first_page(search)
    { numbers: page.map { |number| serialize(number) }, next_page_url: page.next_page_url }
  rescue ::Twilio::REST::RestError => e
    raise ApiError, twilio_message(e)
  end

  # Aponta o voice_url do número para o nosso roteamento. Só é chamado para o
  # número que o cliente escolheu — os demais seguem com o destino que têm.
  def point_voice_webhook(phone_number, url)
    number = client.incoming_phone_numbers.list(phone_number: phone_number).first
    raise ApiError, "Number #{phone_number} not found in this Twilio account" if number.blank?

    client.incoming_phone_numbers(number.sid).update(voice_url: url, voice_method: 'POST')
  rescue ::Twilio::REST::RestError => e
    raise ApiError, twilio_message(e)
  end

  # O que o Twilio tentou e não conseguiu. É o único lugar onde uma chamada
  # perdida antes de chegar até nós deixa rastro: se ele não alcança o nosso
  # webhook, não há log nosso para consultar — nem no Rails, nem no nginx.
  #
  # Duas chamadas foram perdidas assim em 10/08 e só descobrimos porque alguém
  # foi perguntar ao Twilio dias depois.
  def recent_alerts(since: 7.days.ago, limit: 20)
    client.monitor.v1.alerts.list(start_date: since, limit: limit).map { |alert| serialize_alert(alert) }
  rescue ::Twilio::REST::RestError => e
    raise ApiError, twilio_message(e)
  end

  private

  # `alert_text` resume tudo como "Got HTTP 502 response" mesmo quando não houve
  # 502 nenhum — as duas perdas de 10/08 foram falha de DNS, e esse resumo custou
  # uma sessão inteira de diagnóstico na direção errada. Quem diz a verdade é o
  # `response_body`, e ele só vem no fetch individual. Por isso o N+1: são poucos
  # alertas, numa tela que quase nunca é aberta, e o texto certo é o produto.
  def serialize_alert(alert)
    detail = client.monitor.v1.alerts(alert.sid).fetch
    {
      sid: alert.sid,
      error_code: alert.error_code,
      created_at: alert.date_created,
      request_url: alert.request_url,
      request_method: alert.request_method,
      cause: cause_of(detail.response_body),
      docs_url: alert.more_info
    }
  end

  # A linha que interessa é a do `Error:`. As outras são moldura — a primeira
  # repete a URL, que já está na tela, e as últimas trazem SIDs que não ajudam
  # quem está lendo. Alerta sem corpo (os de SMS, por exemplo) fica sem causa, e
  # a tela esconde o campo em vez de mostrar uma linha vazia.
  def cause_of(response_body)
    lines = response_body.to_s.lines.map(&:strip).reject(&:empty?)
    lines.find { |line| line.start_with?('Error:') } || lines.first
  end

  def first_page(search)
    filters = { page_size: PAGE_SIZE }
    filters[:phone_number] = search if search.present?
    client.incoming_phone_numbers.page(**filters)
  end

  def serialize(number)
    {
      sid: number.sid,
      phone_number: number.phone_number,
      friendly_name: number.friendly_name,
      capabilities: {
        sms: number.capabilities['sms'] || false,
        mms: number.capabilities['mms'] || false,
        voice: number.capabilities['voice'] || false
      },
      sms_url: number.sms_url,
      voice_url: number.voice_url
    }
  end

  # A mensagem crua do Twilio já é específica ("Authenticate", "not found"), mas
  # vem sem o código; ele é o que o cliente cola na busca da documentação.
  def twilio_message(error)
    [error.message, ("Twilio code #{error.code}" if error.code)].compact.join(' — ')
  end

  def client
    @client ||= ::Twilio::REST::Client.new(credential.account_sid, credential.auth_token)
  end
end
