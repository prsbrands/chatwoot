# Provedores de cobrança online da conta (Stripe e Mercado Pago). Conectar ou
# trocar a chave valida a chave no provedor (no Stripe, também cria o webhook);
# desligar é active=false (as tentativas e os pagamentos já feitos continuam
# ligados ao provedor). webhook_secret: a chave secreta dos webhooks do Mercado
# Pago, opcional (o Stripe gera a dele sozinho).
class Api::V1::Accounts::Commerce::PaymentProvidersController < Api::V1::Accounts::Commerce::BaseController
  before_action :fetch_provider, only: [:update]
  before_action -> { check_authorization(@provider || ::Commerce::PaymentProvider) }

  def index
    @providers = Current.account.commerce_payment_providers.order(:provider)
  end

  def create
    @provider = Current.account.commerce_payment_providers.new(provider: params.require(:provider))
    save_provider!
    render :show
  end

  def update
    save_provider!
    render :show
  end

  private

  def fetch_provider
    @provider = Current.account.commerce_payment_providers.find(params[:id])
  end

  def save_provider!
    @provider.assign_attributes(params.permit(:environment, :active))
    if params.key?(:credentials)
      @provider.credentials_hash = params.require(:credentials).permit(*::Commerce::PaymentProvider::CREDENTIALS.fetch(@provider.provider, []))
    end
    @provider.webhook_secret = params[:webhook_secret].presence if @provider.mercado_pago? && params.key?(:webhook_secret)
    @provider.validate!
    @provider.gateway.connect! if @provider.new_record? || @provider.credentials_changed? || @provider.environment_changed?
    @provider.save!
  end
end
