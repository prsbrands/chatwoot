# Provedor de cobrança online conectado pela conta (fase 3a: Stripe). As
# credenciais (JSON) e o segredo do webhook ficam cifrados; o webhook_token vai
# na URL do webhook e identifica o provedor da conta sem expor o id dela.
class Commerce::PaymentProvider < ApplicationRecord
  CURRENCIES = { 'stripe' => %w[USD EUR BRL], 'mercado_pago' => %w[BRL], 'yappy' => %w[USD] }.freeze
  # Os que já têm Commerce::Gateways::<Provedor>.
  AVAILABLE = %w[stripe].freeze

  belongs_to :account
  has_many :payment_methods, class_name: 'Commerce::PaymentMethod', foreign_key: :provider_id, inverse_of: :provider,
                             dependent: :nullify
  has_many :checkouts, class_name: 'Commerce::Checkout', foreign_key: :provider_id, inverse_of: :provider, dependent: :restrict_with_error

  enum :provider, { stripe: 0, mercado_pago: 1, yappy: 2 }, validate: true
  enum :environment, { sandbox: 0, production: 1 }, validate: true

  encrypts :credentials
  encrypts :webhook_secret

  validates :provider, uniqueness: { scope: :account_id }, inclusion: { in: AVAILABLE }
  before_validation -> { self.webhook_token ||= SecureRandom.urlsafe_base64(24) }, on: :create

  def credential(key)
    JSON.parse(credentials.presence || '{}')[key.to_s]
  end

  def credentials_hash=(values)
    self.credentials = values.to_h.transform_values { |value| value.to_s.strip }.to_json
  end

  def supports?(currency)
    CURRENCIES.fetch(provider).include?(currency)
  end

  def gateway
    "Commerce::Gateways::#{provider.camelize}".constantize.new(self)
  end

  def webhook_url
    "#{ENV.fetch('FRONTEND_URL')}/commerce/webhooks/#{provider}/#{webhook_token}"
  end

  # Para a tela: só o fim da chave.
  def credential_hint
    key = credential(:secret_key).to_s
    key.present? ? "…#{key.last(4)}" : nil
  end
end
