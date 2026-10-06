# Orçamento, fatura ou recibo por e-mail, com a marca da empresa da conta (não
# a do CortexGen): logo embutido, a mensagem, um quadro com número, total e
# prazo, o botão para o link público (na fatura com cobrança online, "Pagar
# online") e o PDF anexo. Tudo no idioma do documento.
class Commerce::DocumentMailer < ApplicationMailer
  layout false

  def document(document:, pdf:, to:, subject:, body:)
    @document = document
    @labels = Commerce::DocumentLabels.for(document.language)
    @body = body
    @company = document.company || {}
    @public_url = Commerce::DocumentFlow.new(document).public_url
    @pay_online = document.payable? && document.online_payment_methods.any?
    @logo = attach_logo
    attachments[pdf.filename.to_s] = { mime_type: 'application/pdf', content: pdf.download }
    mail(to: to, subject: subject, reply_to: @company['email'].presence)
  end

  private

  # Logo embutido (cid:) em PNG: abre em qualquer cliente de e-mail, sem
  # depender de link externo.
  def attach_logo
    blob = @company['logo_blob_id'] && ActiveStorage::Blob.find_by(id: @company['logo_blob_id'])
    return unless blob

    png = blob.open { |file| ImageProcessing::Vips.source(file.path).convert('png').resize_to_limit(400, 160).call }
    attachments.inline['logo.png'] = File.binread(png.path)
    attachments['logo.png'].url
  rescue StandardError => e
    Rails.logger.warn("[COMMERCE] logo left out of the #{@document.number} email: #{e.message}")
    nil
  end
end
