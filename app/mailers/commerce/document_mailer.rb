# Orçamento ou fatura por e-mail, com o PDF anexo. Texto simples, no idioma do
# documento (montado por Commerce::DocumentSender).
class Commerce::DocumentMailer < ApplicationMailer
  def document(document:, pdf:, to:, subject:, body:, reply_to: nil)
    attachments[pdf.filename.to_s] = { mime_type: 'application/pdf', content: pdf.download }
    mail(to: to, subject: subject, reply_to: reply_to.presence) do |format|
      format.text { render plain: body }
    end
  end
end
