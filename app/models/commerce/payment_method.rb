# Forma de pagamento que a conta aceita, com as instruções que o cliente lê
# (dados bancários, chave Pix, número Yappy...). Na fase 3 ganha o provedor
# online (Stripe, Mercado Pago, Yappy).
class Commerce::PaymentMethod < ApplicationRecord
  belongs_to :account

  enum :kind, { cash: 0, bank_transfer: 1, pix: 2, yappy: 3, card: 4, payment_link: 5, other: 6 }, validate: true

  validates :name, presence: true, length: { maximum: 80 }
end
