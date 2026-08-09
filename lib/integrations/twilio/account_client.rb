# Lê a conta Twilio do cliente: valida as credenciais e lista os números com o
# que cada um sabe fazer. Quem envia e recebe mensagem é o Channel::TwilioSms —
# aqui só descobrimos o que existe antes de provisionar.
class Integrations::Twilio::AccountClient
  class ApiError < StandardError; end

  pattr_initialize [:credential!]

  # O nome da conta no Twilio serve de confirmação visual de que a chave é da
  # conta certa — Account SID sozinho não diz nada para o usuário.
  def friendly_name
    client.api.accounts(credential.account_sid).fetch.friendly_name
  rescue ::Twilio::REST::RestError => e
    raise ApiError, twilio_message(e)
  end

  def phone_numbers
    client.incoming_phone_numbers.list.map { |number| serialize(number) }
  rescue ::Twilio::REST::RestError => e
    raise ApiError, twilio_message(e)
  end

  private

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
