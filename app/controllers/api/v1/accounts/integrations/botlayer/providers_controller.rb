class Api::V1::Accounts::Integrations::Botlayer::ProvidersController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  MASK = '••••••••'.freeze

  rescue_from Integrations::Botlayer::ModelCatalogService::FetchError, with: :render_botlayer_error

  def index
    render json: { providers: client.providers(account_id).map { |provider| mask(provider) } }
  end

  def create
    render json: mask(client.create_provider(account_id, provider_params))
  end

  # A chave só é reescrita quando o formulário envia um valor novo; campo vazio
  # mantém a que já está gravada.
  def update
    attributes = provider_params.except(:slug)
    attributes = attributes.except(:api_key) if attributes[:api_key].blank?
    render json: mask(client.update_provider(account_id, params[:id], attributes))
  end

  def destroy
    client.delete_provider(account_id, params[:id])
    head :ok
  end

  def sync_models
    provider = client.provider(account_id, params[:id])
    return head :not_found if provider.blank?

    models = Integrations::Botlayer::ModelCatalogService.new(provider: provider).perform
    render json: mask(client.update_provider(account_id, params[:id], { models: models }))
  end

  private

  def required_feature
    'ai_providers'
  end

  def account_id
    Current.account.id
  end

  def mask(provider)
    return provider if provider.blank?

    provider.merge('api_key' => provider['api_key'].present? ? MASK : nil)
  end

  def provider_params
    params.permit(:slug, :label, :base_url, :api_style, :api_key, :is_active)
  end
end
