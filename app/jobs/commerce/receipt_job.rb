# Emite o recibo de um pagamento e o envia ao cliente pelos canais da fatura.
# notify: nota interna na conversa (pagamento online, que ninguém da equipe
# registrou). user_id: quem registrou o pagamento à mão, remetente do envio.
class Commerce::ReceiptJob < ApplicationJob
  queue_as :default

  def perform(payment_id, notify: false, user_id: nil)
    issuer = Commerce::ReceiptIssuer.new(Commerce::DocumentPayment.find(payment_id), user: user_id && User.find(user_id))
    receipt = issuer.issue!
    issuer.notify!(receipt) if notify
    issuer.deliver!(receipt)
  end
end
