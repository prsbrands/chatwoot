# A página do documento para o cliente, sem login: o token aleatório do link é a
# chave (por isso sem CSRF, como os outros PublicController). Mostra o orçamento,
# a fatura ou o recibo no idioma do cliente, baixa o PDF, deixa aceitar ou
# recusar o orçamento aberto e pagar a fatura online (inteira ou uma parte).
# Na volta do provedor (?checkout=), pergunta a ele se já pagou, sem esperar o
# webhook.
class CommercePublicDocumentsController < PublicController
  layout false
  before_action :fetch_document

  def show
    @checkout = @document.checkouts.find_by(id: params[:checkout]) if params[:checkout]
    refresh_checkout if @checkout&.pending?
  end

  def pay
    method = @document.account.commerce_payment_methods.online.find(params.require(:payment_method_id))
    checkout = ::Commerce::CheckoutStarter.new(@document, payment_method: method, amount: params[:amount])
                                          .start!(::Commerce::DocumentFlow.new(@document).public_url)
    redirect_to checkout.checkout_url, allow_other_host: true
  rescue ::Commerce::Gateways::Error, ActiveRecord::RecordNotFound
    @pay_error = true
    render :show, status: :unprocessable_entity
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

    @labels = ::Commerce::DocumentLabels.for(@document.language)
  end

  def refresh_checkout
    ::Commerce::CheckoutSettler.new(@checkout).refresh!
    @checkout.reload
    @document.reload
  rescue ::Commerce::Gateways::Error
    nil
  end

  def answerable?
    @document.quote? && @document.sent? && @document.display_status != 'expired'
  end
end
