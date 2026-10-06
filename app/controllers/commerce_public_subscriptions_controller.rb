# A página da assinatura para o cliente, sem login (o token do link é a chave):
# mostra o plano, o valor e o ciclo, e leva ao provedor para assinar. Na volta
# (?session_id=), avisa que a confirmação chega pelo provedor; quem ativa a
# assinatura é o aviso do primeiro ciclo pago.
class CommercePublicSubscriptionsController < PublicController
  layout false
  before_action :fetch_subscription

  def show; end

  def subscribe
    url = ::Commerce::SubscriptionBilling.new(@subscription).start!(commerce_public_subscription_url(@subscription.public_token))
    redirect_to url, allow_other_host: true
  rescue ::Commerce::Gateways::Error
    @subscribe_error = true
    render :show, status: :unprocessable_entity
  end

  private

  def fetch_subscription
    @subscription = ::Commerce::Subscription.find_by!(public_token: params[:token])
    @labels = ::Commerce::DocumentLabels.for(@subscription.language)
    @profile = ::Commerce::Profile.for(@subscription.account)
  end
end
