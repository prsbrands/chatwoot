# Envia o documento ao cliente: pela conversa (o PDF vai como anexo, com o link
# público) ou por e-mail (PDF anexo). Envia sempre o PDF mais recente do
# arquivo, gerando um se ainda não houver; o envio tira o documento do rascunho.
# Guarda a conversa e o e-mail usados: o recibo segue pelos mesmos canais.
class Commerce::DocumentSender
  # Canal API sem webhook (a caixa de voz) não entrega nada ao cliente.
  def self.deliverable?(conversation)
    !(conversation.inbox.api? && conversation.inbox.channel.webhook_url.blank?)
  end

  def initialize(document, user)
    @document = document
    @user = user
    @flow = Commerce::DocumentFlow.new(document, user: user)
    @labels = Commerce::DocumentLabels.for(document.language)
  end

  def to_conversation!(conversation, content = nil)
    unless self.class.deliverable?(conversation)
      @document.errors.add(:base, "#{conversation.inbox.name} does not deliver messages to the customer")
      raise ActiveRecord::RecordInvalid, @document
    end

    pdf = pdf_attachment
    Messages::MessageBuilder.new(@user, conversation, {
                                   message_type: 'outgoing',
                                   content: content.presence || default_message,
                                   attachments: [pdf.blob.signed_id]
                                 }).perform
    @document.update!(conversation: conversation)
    @flow.mark_sent!
  end

  def to_email!(to, subject: nil, body: nil)
    pdf = pdf_attachment
    Commerce::DocumentMailer.document(document: @document, pdf: pdf, to: to,
                                      subject: subject.presence || default_subject,
                                      body: body.presence || default_email_body).deliver_now
    @document.update!(delivered_email: to)
    @flow.mark_sent!
  end

  private

  def pdf_attachment
    @document.latest_pdf || @flow.archive_pdf!
  end

  def document_name
    @labels[@document.kind.to_sym]
  end

  def default_subject
    "#{document_name} #{@document.number} — #{@document.company['trade_name'].presence || @document.company['legal_name']}".strip.delete_suffix(' —')
  end

  def default_message
    format(@labels[:message], document: document_name, number: @document.number, url: @flow.public_url)
  end

  # O link vai no botão do e-mail (Commerce::DocumentMailer), não no texto.
  def default_email_body
    name = @document.customer['name'].presence || ''
    [format(@labels[:email_greeting], name: name).sub(' ,', ','), '',
     format(@labels[:email_body], document: document_name.downcase, number: @document.number), '',
     @labels[:email_thanks]].join("\n")
  end
end
