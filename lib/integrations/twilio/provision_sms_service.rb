# Liga um número da conta Twilio a uma inbox de SMS:
#   1. Canal Channel::TwilioSms com uma cópia das credenciais da conta (é assim
#      que o Chatwoot funciona — a inbox sobrevive à desconexão da integração).
#   2. Inbox.
#   3. Escreve o sms_url no número, na própria API do Twilio, para o cliente não
#      precisar colar webhook nenhum no console.
class Integrations::Twilio::ProvisionSmsService
  pattr_initialize [:account!, :credential!, :phone_number!, :name!]

  def perform
    ActiveRecord::Base.transaction do
      channel = account.twilio_sms.create!(
        account_sid: credential.account_sid,
        auth_token: credential.auth_token,
        phone_number: phone_number,
        medium: :sms
      )
      inbox = account.inboxes.create!(name: name, channel: channel)
      ::Twilio::WebhookSetupService.new(inbox: inbox).perform
      inbox
    end
  end
end
