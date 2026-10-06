# Avisos dos provedores de cobrança online. O token da URL acha o provedor da
# conta e a assinatura é verificada com o segredo dele antes de tocar no banco;
# o corpo de um aviso recusado não vai para o log.
class Commerce::WebhooksController < ActionController::API
  def create
    provider = ::Commerce::PaymentProvider.find_by!(provider: params[:provider], webhook_token: params[:token])
    lookup, result = provider.gateway.webhook(request)
    checkout = lookup && provider.checkouts.find_by(lookup)
    ::Commerce::CheckoutSettler.new(checkout).apply!(result) if checkout
    head :ok
  rescue ::Commerce::Gateways::InvalidSignature
    head :bad_request
  end
end
