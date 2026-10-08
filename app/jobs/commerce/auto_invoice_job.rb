# O cliente aceitou a cotização pelo link e a conta liga "fatura automática"
# (commerce_profiles.auto_invoice_on_accept): a fatura nasce da cotização e vai
# pelos canais dela (a conversa e o último e-mail), com nota interna para a
# equipe. Cotização que já tem fatura não gera outra.
class Commerce::AutoInvoiceJob < ApplicationJob
  queue_as :default

  def perform(quote_id)
    quote = Commerce::Document.find(quote_id)
    return if Commerce::Document.invoice.exists?(source_document_id: quote.id)

    invoice = Commerce::DocumentFlow.new(quote).to_invoice!
    sender = Commerce::DocumentSender.new(invoice, nil)
    conversation = quote.conversation
    sender.to_conversation!(conversation) if conversation && Commerce::DocumentSender.deliverable?(conversation)
    sender.to_email!(quote.delivered_email) if quote.delivered_email.present?
    note(conversation, quote, invoice) if conversation
  end

  private

  def note(conversation, quote, invoice)
    conversation.messages.create!(account: quote.account, inbox: conversation.inbox, message_type: :outgoing, private: true,
                                  content: I18n.t('commerce.auto_invoice', quote: quote.number, invoice: invoice.number))
  end
end
