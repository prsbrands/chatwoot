class VoiceAgent::ConfigsController < VoiceAgent::BaseController
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Voice::CallConfigService::MisconfiguredError, Integrations::Botlayer::Client::ApiError, with: :render_misconfigured

  # O serviço de mídia pergunta pelo número discado, que é o que ele recebe do
  # Twilio no evento `start` do stream.
  def show
    route = TwilioVoiceRoute.find_by!(phone_number: params[:phone_number], enabled: true)
    render json: Voice::CallConfigService.new(route: route).perform
  end

  private

  def render_not_found
    render json: { error: "no enabled voice route for #{params[:phone_number]}" }, status: :not_found
  end

  def render_misconfigured(exception)
    Rails.logger.error("VOICE_CONFIG_MISCONFIGURED number=#{params[:phone_number]} #{exception.message}")
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
