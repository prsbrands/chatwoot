class VoiceAgent::CallsController < VoiceAgent::BaseController
  # O serviço de mídia manda isto quando a chamada acaba: quem ligou, o que foi
  # dito e por quanto tempo.
  def create
    route = TwilioVoiceRoute.find_by!(phone_number: params[:phone_number])
    conversation = Voice::CallReportService.new(route: route, params: report_params).perform
    render json: { conversation_id: conversation.id, inbox_id: conversation.inbox_id }
  end

  private

  def report_params
    params.permit(
      :call_sid, :phone_number, :from_number, :duration_seconds, :summary,
      :name, :email, :company, :city, :whatsapp, :timeline, :interest, :fit,
      transcript: [:role, :content],
      metrics: [:turns, :prompt_tokens, :completion_tokens, :tts_characters,
                :stt_seconds, :latency_median_ms, :latency_worst_ms]
    )
  end
end
