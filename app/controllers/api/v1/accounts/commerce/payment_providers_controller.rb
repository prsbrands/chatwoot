# Provedores de cobrança online da conta (fase 3a: Stripe). Conectar ou trocar a
# chave valida a chave no provedor e cria o webhook; desligar é active=false
# (as tentativas e os pagamentos já feitos continuam ligados ao provedor).
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
    @provider.credentials_hash = params.require(:credentials).permit(:secret_key) if params.key?(:credentials)
    @provider.validate!
    @provider.gateway.connect! if @provider.new_record? || @provider.credentials_changed? || @provider.environment_changed?
    @provider.save!
  end
end
