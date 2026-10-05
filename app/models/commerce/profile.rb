# Os dados da empresa que saem nos orçamentos e faturas: logo, nome, documento
# fiscal, contatos e os textos padrão. Uma linha por conta, criada na primeira
# leitura.
class Commerce::Profile < ApplicationRecord
  belongs_to :account
  has_one_attached :logo

  validates :default_currency, inclusion: { in: Commerce::CURRENCIES }
  validates :trade_name, :legal_name, :tax_id_label, :tax_id, :phone, :whatsapp, :email, :website, length: { maximum: 160 }

  def self.for(account)
    find_or_create_by!(account: account)
  rescue ActiveRecord::RecordNotUnique
    find_by!(account: account)
  end
end
