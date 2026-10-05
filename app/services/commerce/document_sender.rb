# Envia o documento ao cliente: pela conversa (o PDF vai como anexo, com o link
# público) ou por e-mail (PDF anexo). Envia sempre o PDF mais recente do
# arquivo, gerando um se ainda não houver; o envio tira o documento do rascunho.
class Commerce::DocumentSender
  def initialize(document, user)
    @document = document
    @user = user
    @flow = Commerce::DocumentFlow.new(document, user: user)
    @labels = Commerce::DocumentLabels.for(document.language)
  end

  def to_conversation!(conversation, content = nil)
    # Canal API sem webhook (a caixa de voz) não entrega nada ao cliente.
    if conversation.inbox.api? && conversation.inbox.channel.webhook_url.blank?
      @document.errors.add(:base, "#{conversation.inbox.name} does not deliver messages to the customer")
      raise ActiveRecord::RecordInvalid, @document
    end

    pdf = pdf_attachment
    Messages::MessageBuilder.new(@user, conversation, {
                                   message_type: 'outgoing',
                                   content: content.presence || default_message,
                                   attachments: [pdf.blob.signed_id]
                                 }).perform
    @flow.mark_sent!
  end

  def to_email!(to, subject: nil, body: nil)
    pdf = pdf_attachment
    Commerce::DocumentMailer.document(pdf: pdf, to: to, subject: subject.presence || default_subject,
                                      body: body.presence || default_email_body, reply_to: @document.company['email']).deliver_now
    @flow.mark_sent!
  end

  private

  def pdf_attachment
    @document.latest_pdf || @flow.archive_pdf!
  end

  def document_name
    @labels[@document.quote? ? :quote : :invoice]
  end

  def default_subject
    "#{document_name} #{@document.number} — #{@document.company['trade_name'].presence || @document.company['legal_name']}".strip.delete_suffix(' —')
  end

  def default_message
    format(@labels[:message], document: document_name, number: @document.number, url: @flow.public_url)
  end

  def default_email_body
    name = @document.customer['name'].presence || ''
    [format(@labels[:email_greeting], name: name).sub(' ,', ','), '',
     format(@labels[:email_body], document: document_name.downcase, number: @document.number), '',
     @labels[:email_link], @flow.public_url, '', @labels[:email_thanks]].join("\n")
  end
end
