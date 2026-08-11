class VoiceAgent::ConfigsController < VoiceAgent::BaseController
  # Número sem rota cai no 404 do próprio Chatwoot, que já responde antes daqui.
  rescue_from Voice::CallConfigService::MisconfiguredError, Integrations::Botlayer::Client::ApiError, with: :render_misconfigured

  # O serviço de mídia pergunta pelo número discado, que é o que ele recebe do
  # Twilio no evento `start` do stream.
  def show
    route = TwilioVoiceRoute.find_by!(phone_number: params[:phone_number], enabled: true)
    # `persona_slug` só vem em chamada de saída, onde o roteiro é de quem liga e
    # não o da rota, que é de quem atende.
    render json: Voice::CallConfigService.new(route: route, persona_slug: params[:persona_slug]).perform
  end

  private

  def render_misconfigured(exception)
    Rails.logger.error("VOICE_CONFIG_MISCONFIGURED number=#{params[:phone_number]} #{exception.message}")
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
