# Uma tentativa de pagamento online: o cliente clicou em "Pagar" na página do
# documento. Só vira pagamento (Commerce::DocumentPayment) quando o provedor
# confirma, pelo webhook ou pela conciliação; quem desiste fica aqui, pending
# até expirar.
class Commerce::Checkout < ApplicationRecord
  EXPIRES_IN = 24.hours

  belongs_to :account
  belongs_to :document, class_name: 'Commerce::Document'
  belongs_to :provider, class_name: 'Commerce::PaymentProvider', inverse_of: :checkouts
  belongs_to :payment_method, class_name: 'Commerce::PaymentMethod', optional: true
  has_one :payment, class_name: 'Commerce::DocumentPayment', dependent: :nullify, inverse_of: :checkout

  enum :status, { pending: 0, paid: 1, failed: 2, expired: 3 }, validate: true

  validates :amount, numericality: { greater_than: 0 }
end
