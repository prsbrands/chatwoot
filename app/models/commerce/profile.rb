# Os dados da empresa que saem nos orçamentos e faturas: logo, nome, documento
# fiscal, contatos e os textos padrão. Uma linha por conta, criada na primeira
# leitura. Também liga a vitrine pública do catálogo (/c/:storefront_token),
# cujo token nasce na primeira vez que ela é ligada.
class Commerce::Profile < ApplicationRecord
  belongs_to :account
  has_one_attached :logo

  validates :default_currency, inclusion: { in: Commerce::CURRENCIES }
  before_validation { %i[quote_prefix invoice_prefix receipt_prefix].each { |field| self[field] = self[field].to_s.strip.upcase } }
  validates :quote_prefix, :invoice_prefix, :receipt_prefix, format: { with: /\A[A-Z0-9]{1,8}\z/ }
  validates :trade_name, :legal_name, :tax_id_label, :tax_id, :phone, :whatsapp, :email, :website, length: { maximum: 160 }
  before_save -> { self.storefront_token ||= SecureRandom.urlsafe_base64(16) }, if: :storefront_enabled

  def storefront_url
    "#{ENV.fetch('FRONTEND_URL')}/c/#{storefront_token}" if storefront_token
  end

  def self.for(account)
    find_or_create_by!(account: account)
  rescue ActiveRecord::RecordNotUnique
    find_by!(account: account)
  end
end
