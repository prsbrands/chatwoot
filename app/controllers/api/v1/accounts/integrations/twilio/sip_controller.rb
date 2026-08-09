class Api::V1::Accounts::Integrations::Twilio::SipController < Api::V1::Accounts::Integrations::Twilio::BaseController
  rescue_from Integrations::Twilio::SipService::ApiError, with: :render_twilio_error

  def index
    render json: { domains: sip.domains }
  end

  def create
    render json: sip.create_domain(params[:subdomain])
  end

  def credentials
    render json: { credentials: sip.credentials(params[:id]) }
  end

  def create_credential
    render json: sip.create_credential(params[:id], params[:username])
  end

  def destroy_credential
    sip.delete_credential(params[:id], params[:credential_sid])
    head :ok
  end

  private

  def sip
    @sip ||= Integrations::Twilio::SipService.new(credential: credential)
  end
end
