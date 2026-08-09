class Api::V1::Accounts::Integrations::Twilio::VoiceRoutesController < Api::V1::Accounts::Integrations::Twilio::BaseController
  def index
    render json: { routes: Current.account.twilio_voice_routes, calls: recent_calls }
  end

  # Salvar a rota também aponta o voice_url do número para cá, na API do Twilio:
  # sem isso a regra existe no painel e a ligação continua indo para onde estava.
  def create
    route = Current.account.twilio_voice_routes.find_or_initialize_by(phone_number: route_params[:phone_number])
    route.assign_attributes(route_params)
    return render json: { error: route.errors.full_messages.to_sentence }, status: :unprocessable_entity unless route.save

    point_number_to_us(route.phone_number)
    render json: route
  end

  def destroy
    Current.account.twilio_voice_routes.find(params[:id]).destroy!
    head :ok
  end

  private

  def point_number_to_us(phone_number)
    client.point_voice_webhook(phone_number, twilio_voice_incoming_url(host: ENV.fetch('FRONTEND_URL', nil)))
  end

  def recent_calls
    Current.account.twilio_voice_calls.order(id: :desc).limit(20)
  end

  def route_params
    params.permit(:phone_number, :destination_type, :destination, :ring_timeout, :enabled,
                  :answer_mode, :no_answer_action, :bot_persona_slug)
  end
end
