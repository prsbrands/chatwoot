# Uma pessoa da lista da campanha. O contato do Chatwoot só aparece quando ela
# responde (o adaptador do OpenWA cria a conversa nesse momento), então uma lista
# fria não enche o CRM de quem a campanha nunca tocou. `sending` é o envio em
# andamento: se o job morrer no meio, ele fica `sending` e a varredura o marca
# como falha, sem reenviar (envio incerto nunca é repetido).
class Outreach::Recipient < ApplicationRecord
  self.table_name = 'outreach_recipients'

  belongs_to :account
  belongs_to :campaign, class_name: 'Outreach::Campaign'
  belongs_to :contact, optional: true

  enum :status, { pending: 0, excluded: 1, sending: 2, sent: 3, replied: 4, failed: 5, opted_out: 6, cancelled: 7 }, validate: true

  scope :delivered, -> { where(status: [:sent, :replied, :opted_out]) }

  def first_name
    name.to_s.split.first
  end

  # O WhatsApp endereça o chat pelo telefone sem o "+".
  def chat_id
    "#{phone.delete('+')}@c.us"
  end
end
