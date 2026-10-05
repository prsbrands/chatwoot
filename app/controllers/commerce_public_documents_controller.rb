# A página do documento para o cliente, sem login: o token aleatório do link é a
# chave (por isso sem CSRF, como os outros PublicController). Mostra o orçamento
# ou a fatura no idioma do cliente, baixa o PDF e, no orçamento ainda aberto,
# deixa aceitar ou recusar.
class CommercePublicDocumentsController < PublicController
  layout false
  before_action :fetch_document

  def show
    @labels = ::Commerce::DocumentLabels.for(@document.language)
  end

  def pdf
    attachment = @document.latest_pdf || ::Commerce::DocumentFlow.new(@document).archive_pdf!
    send_data attachment.download, filename: "#{@document.number}.pdf", type: 'application/pdf', disposition: 'inline'
  end

  def accept
    ::Commerce::DocumentFlow.new(@document).accept! if answerable?
    redirect_to commerce_public_document_path(@document.public_token)
  end

  def decline
    ::Commerce::DocumentFlow.new(@document).decline! if answerable?
    redirect_to commerce_public_document_path(@document.public_token)
  end

  private

  def fetch_document
    @document = ::Commerce::Document.find_by!(public_token: params[:token])
    raise ActiveRecord::RecordNotFound if @document.draft?
  end

  def answerable?
    @document.quote? && @document.sent? && @document.display_status != 'expired'
  end
end
