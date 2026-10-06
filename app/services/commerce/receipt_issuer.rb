# Recibo de um pagamento da fatura: um documento kind receipt com o valor, a
# forma, a data e a posição da fatura depois deste pagamento (total, pago até
# aqui e saldo). O envio usa os canais por onde a fatura foi: a conversa dela e o
# último e-mail usado. A nota interna avisa a equipe do pagamento online.
class Commerce::ReceiptIssuer
  def initialize(payment, user: nil)
    @payment = payment
    @invoice = payment.document
    @user = user
  end

  def issue!
    return @payment.receipt if @payment.receipt

    Commerce::Document.transaction do
      receipt = @invoice.account.commerce_documents.create!(
        @invoice.slice(:language, :currency, :contact_id, :deal_id, :conversation_id, :customer, :company, :footer)
                .merge(kind: :receipt, tax_mode: :exempt, issue_date: @payment.paid_on, source_document: @invoice, created_by: @user,
                       subtotal: @payment.amount, total: @payment.amount, details: details)
      )
      @payment.update!(receipt: receipt)
      receipt
    end
  end

  def deliver!(receipt)
    sender = Commerce::DocumentSender.new(receipt, @user)
    conversation = @invoice.conversation
    sender.to_conversation!(conversation) if conversation && Commerce::DocumentSender.deliverable?(conversation)
    sender.to_email!(@invoice.delivered_email) if @invoice.delivered_email.present?
  end

  def notify!(receipt)
    conversation = @invoice.conversation
    return unless conversation

    amount = Commerce::DocumentLabels.money(@payment.amount, @invoice.currency, 'en')
    conversation.messages.create!(account: @invoice.account, inbox: conversation.inbox, message_type: :outgoing, private: true,
                                  content: I18n.t('commerce.online_payment', amount: amount, invoice: @invoice.number,
                                                                             method: @payment.payment_method&.name, receipt: receipt.number))
  end

  private

  def details
    paid_to_date = @invoice.payments.where(id: ..@payment.id).sum(:amount)
    {
      invoice_number: @invoice.number, invoice_total: @invoice.total.to_s, paid_to_date: paid_to_date.to_s,
      balance: (@invoice.total - paid_to_date).to_s, method: @payment.payment_method&.name, paid_on: @payment.paid_on.to_s,
      reference: @payment.checkout&.external_id
    }
  end
end
