# Dispara uma ligação do bot para um número. Admin-only, como o resto da
# integração: uma ligação custa dinheiro e toca no telefone de alguém.
class Api::V1::Accounts::Integrations::Twilio::VoiceCallsController < Api::V1::Accounts::Integrations::Twilio::BaseController
  rescue_from Voice::OutboundCallService::Error, with: :render_call_error

  def create
    route = Current.account.twilio_voice_routes.find_by!(phone_number: params[:phone_number], enabled: true)
    call = Voice::OutboundCallService.new(
      route: route,
      to: params[:to],
      persona_slug: params[:persona_slug]
    ).perform

    render json: { call_sid: call.sid, status: call.status, to: call.to }
  end

  private

  def render_call_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end
end
