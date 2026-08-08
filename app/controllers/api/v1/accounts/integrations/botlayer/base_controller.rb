class Api::V1::Accounts::Integrations::Botlayer::BaseController < Api::V1::Accounts::BaseController
  before_action -> { check_admin_authorization? }
  before_action :ensure_configured

  rescue_from Integrations::Botlayer::Client::ApiError, with: :render_botlayer_error

  private

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
