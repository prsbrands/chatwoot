class Api::V1::Accounts::Integrations::Botlayer::BaseController < Api::V1::Accounts::BaseController
  before_action -> { check_admin_authorization? }
  before_action :ensure_feature_enabled
  before_action :ensure_configured

  rescue_from Integrations::Botlayer::Client::ApiError, with: :render_botlayer_error

  private

  # Ligado por conta no Super Admin. Personas e chaves de LLM são features
  # separadas — ver Integrations::App#botlayer_enabled?.
  def required_feature
    'bot_personas'
  end

  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?(required_feature)
  end

  def ensure_configured
    return if Integrations::Botlayer::Client.configured?

    render json: { error: I18n.t('errors.botlayer.not_configured') }, status: :unprocessable_entity
  end

  def render_botlayer_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def client
    @client ||= Integrations::Botlayer::Client.new
  end
end
