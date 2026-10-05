# Pagamento recebido de uma fatura (registro manual; na fase 3 a cobrança online
# grava aqui também). A soma vira amount_paid e a situação da fatura.
class Commerce::DocumentPayment < ApplicationRecord
  belongs_to :account
  belongs_to :document, class_name: 'Commerce::Document', inverse_of: :payments
  belongs_to :payment_method, class_name: 'Commerce::PaymentMethod', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :paid_on, presence: true
end
