class Api::V1::Accounts::Integrations::Twilio::BaseController < Api::V1::Accounts::BaseController
  before_action -> { check_admin_authorization? }
  before_action :ensure_feature_enabled

  rescue_from Integrations::Twilio::AccountClient::ApiError, with: :render_twilio_error

  private

  # Ligado por conta no Super Admin, como as demais integrações do stack.
  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('twilio_integration')
  end

  def credential
    @credential ||= Current.account.twilio_credential
  end

  def client
    @client ||= Integrations::Twilio::AccountClient.new(credential: credential)
  end

  def render_twilio_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
