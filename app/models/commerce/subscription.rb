# Assinatura mensal ou anual de um plano (item do catálogo com
# billing_interval). Nasce aguardando: a equipe manda o link /s/:token e o
# cliente assina pelo provedor da forma de pagamento escolhida. Cada ciclo pago
# vira uma fatura (documents.subscription_id) já paga, com o recibo enviado
# pelos canais da assinatura (Commerce::SubscriptionBilling).
class Commerce::Subscription < ApplicationRecord
  # Provedores que cobram assinatura. Os ASSISTED não têm débito automático: a
  # fatura de cada ciclo vai ao cliente com o link de pagamento.
  PROVIDERS = %w[stripe mercado_pago yappy].freeze
  ASSISTED = %w[yappy].freeze

  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :deal, class_name: 'Sales::Deal', optional: true
  belongs_to :conversation, optional: true
  belongs_to :item, class_name: 'Commerce::Item', optional: true
  belongs_to :provider, class_name: 'Commerce::PaymentProvider'
  belongs_to :payment_method, class_name: 'Commerce::PaymentMethod', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :invoices, -> { order(:issue_date, :id) }, class_name: 'Commerce::Document', dependent: :nullify, inverse_of: :subscription

  enum :interval, { month: 1, year: 2 }, validate: true
  # past_due: o provedor não conseguiu cobrar o ciclo e segue tentando.
  enum :status, { pending: 0, active: 1, past_due: 2, canceled: 3 }, validate: true

  validates :name, presence: true, length: { maximum: 160 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than: 0 }
  validates :currency, inclusion: { in: Commerce::CURRENCIES }
  validates :language, inclusion: { in: Commerce::Document::LANGUAGES }
  validate :provider_charges_recurring
  validate :item_is_plan, on: :create

  before_validation :copy_plan, :copy_customer, on: :create

  def amount
    (quantity * unit_price).round(2)
  end

  def public_url
    "#{ENV.fetch('FRONTEND_URL')}/s/#{public_token}"
  end

  def assisted?
    ASSISTED.include?(provider.provider)
  end

  # O cliente ainda pode assinar pelo link.
  def subscribable?
    pending? && payment_method&.online? && provider.active
  end

  private

  # A assinatura guarda a cópia do plano e do cliente, e o provedor da forma de
  # pagamento: o catálogo e o contato podem mudar depois.
  def copy_plan
    self.public_token ||= SecureRandom.urlsafe_base64(24)
    self.provider ||= payment_method&.provider
    assign_attributes(name: item.name, unit_price: item.price, currency: item.currency, interval: item.billing_interval) if item && name.blank?
  end

  # Com os dados fiscais lembrados do último documento (billing_*) e o negócio
  # aberto do contato, que é ganho no primeiro ciclo pago.
  def copy_customer
    return if contact.nil? || customer.present?

    self.deal ||= account.sales_deals.open.find_by(contact: contact)
    billing = (contact.additional_attributes || {}).slice('billing_tax_id_label', 'billing_tax_id', 'billing_address')
                                                   .transform_keys { |key| key.delete_prefix('billing_') }
    self.customer = { 'name' => contact.name, 'email' => contact.email, 'phone' => contact.phone_number }.merge(billing).compact_blank
  end

  def item_is_plan
    errors.add(:item, :invalid) if item&.billed_one_time?
  end

  def provider_charges_recurring
    return if provider.nil?

    errors.add(:provider, :invalid) unless provider.account_id == account_id && PROVIDERS.include?(provider.provider) &&
                                           provider.supports?(currency)
  end
end
