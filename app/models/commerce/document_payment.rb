# Pagamento recebido de uma fatura: registrado à mão ou confirmado pelo
# provedor online (checkout). A soma vira amount_paid e a situação da fatura;
# o recibo (documento kind receipt) fica em receipt.
class Commerce::DocumentPayment < ApplicationRecord
  belongs_to :account
  belongs_to :document, class_name: 'Commerce::Document', inverse_of: :payments
  belongs_to :payment_method, class_name: 'Commerce::PaymentMethod', optional: true
  belongs_to :checkout, class_name: 'Commerce::Checkout', optional: true, inverse_of: :payment
  belongs_to :receipt, class_name: 'Commerce::Document', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :paid_on, presence: true

  def online?
    checkout_id.present?
  end
end
