# Forma de pagamento que a conta aceita, com as instruções que o cliente lê
# (dados bancários, chave Pix, número Yappy...). Com um provedor conectado
# (Stripe), vira cobrança online: o botão "Pagar" da fatura.
class Commerce::PaymentMethod < ApplicationRecord
  belongs_to :account
  belongs_to :provider, class_name: 'Commerce::PaymentProvider', optional: true, inverse_of: :payment_methods
  # Forma com pagamento ou cobrança registrada fica no histórico: desative em vez de excluir.
  has_many :payments, class_name: 'Commerce::DocumentPayment', dependent: :restrict_with_error
  has_many :checkouts, class_name: 'Commerce::Checkout', dependent: :restrict_with_error

  enum :kind, { cash: 0, bank_transfer: 1, pix: 2, yappy: 3, card: 4, payment_link: 5, other: 6 }, validate: true

  validates :name, presence: true, length: { maximum: 80 }
  validate :provider_in_account
  before_destroy :remove_from_documents

  scope :online, -> { where(active: true).joins(:provider).where(commerce_payment_providers: { active: true }) }

  def online?
    active && provider&.active
  end

  private

  # Os documentos guardam os ids escolhidos; um id que sumiu faria o editor recusar o salvamento.
  def remove_from_documents
    account.commerce_documents.where('? = ANY(payment_method_ids)', id)
           .update_all(['payment_method_ids = array_remove(payment_method_ids, ?)', id])
  end

  def provider_in_account
    errors.add(:provider_id, :invalid) if provider && provider.account_id != account_id
  end
end
