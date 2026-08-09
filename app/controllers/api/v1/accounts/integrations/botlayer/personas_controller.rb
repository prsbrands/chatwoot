class Api::V1::Accounts::Integrations::Botlayer::PersonasController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  def index
    render json: { personas: client.personas }
  end

  def create
    render json: client.create_persona(persona_params)
  end

  def update
    render json: client.update_persona(params[:id], persona_params.except(:slug))
  end

  def destroy
    client.delete_persona(params[:id])
    head :ok
  end

  private

  def persona_params
    permitted = params.permit(:slug, :display_name, :description, :system_prompt, :provider, :model,
                              :fallback_provider, :fallback_model, :temperature, :max_tokens, :is_active,
                              :stt_provider, :stt_model, :tts_provider, :tts_voice_id, :tts_model,
                              :voice_language, :stt_language, :voice_first_message, :voice_greeting_delay_ms,
                              :voice_endpoint_ms, :voice_interruptible,
                              handoff_rules: {}).to_h
    # handoff_rules.keywords chega como array; permit com hash aberto não cobre
    # arrays aninhados, então normalizamos aqui a partir do raw.
    permitted['handoff_rules'] = params[:handoff_rules].permit!.to_h if params[:handoff_rules].present?
    permitted
  end
end
