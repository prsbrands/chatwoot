# Número que a operação não quer em campanha ("é o contador", "é concorrente").
# Diferente do opt-out: quem pediu para parar vira contato bloqueado e some do
# atendimento inteiro; aqui o atendimento continua respondendo normalmente.
class Outreach::Suppression < ApplicationRecord
  self.table_name = 'outreach_suppressions'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  validates :phone, presence: true, uniqueness: { scope: :account_id }
  validates :phone, format: { with: Outreach::Phone::E164 }

  # Vários números de um texto (um por linha, vírgula ou ponto e vírgula).
  # Devolve quantos entraram e os que não viraram telefone.
  def self.add_all(account, text, country:, reason:, user:)
    phones = text.split(/[\n,;]+/).map(&:strip).compact_blank.index_with { |entry| Outreach::Phone.normalize(entry, country: country) }
    fresh = phones.values.compact.uniq - account.outreach_suppressions.where(phone: phones.values.compact).pluck(:phone)
    fresh.each { |phone| account.outreach_suppressions.create!(phone: phone, reason: reason, created_by: user) }
    { added: fresh.size, invalid: phones.select { |_entry, phone| phone.nil? }.keys }
  end
end
