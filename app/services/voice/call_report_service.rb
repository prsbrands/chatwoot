# O que sobra de uma chamada depois que ela termina: quem ligou, o que foi dito
# e por quanto tempo. Sem isto a chamada só existe no log do serviço de mídia —
# quem vende não vê nada.
class Voice::CallReportService
  def initialize(route:, params:)
    @route = route
    @params = params
  end

  def perform
    conversation = build_conversation
    record_transcript(conversation)
    record_summary(conversation)
    update_call(conversation)
    conversation
  end

  private

  def account
    @route.account
  end

  # Chamada não vira mensagem numa inbox de SMS de propósito: ali uma mensagem
  # de saída é enviada de verdade pelo Twilio, e devolver a transcrição ao
  # cliente por SMS seria um belo acidente. Inbox de API não envia nada sozinha.
  def inbox
    @inbox ||= account.inboxes.find_by(id: @route.voice_inbox_id) || create_inbox
  end

  def create_inbox
    channel = Channel::Api.create!(account: account)
    inbox = account.inboxes.create!(name: "Voz — #{@route.phone_number}", channel: channel)
    @route.update!(voice_inbox_id: inbox.id)
    inbox
  end

  # O número de quem ligou é a identidade: a mesma pessoa ligando de novo cai no
  # mesmo contato, e o histórico se acumula.
  def contact_inbox
    @contact_inbox ||= ContactInboxWithContactBuilder.new(
      inbox: inbox,
      source_id: caller_number,
      contact_attributes: { name: caller_number, phone_number: caller_number }
    ).perform
  end

  def caller_number
    @params[:from_number].presence || 'unknown'
  end

  def build_conversation
    Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact_inbox.contact,
      contact_inbox: contact_inbox,
      additional_attributes: {
        call_sid: @params[:call_sid],
        called_number: @route.phone_number,
        duration_seconds: @params[:duration_seconds]
      }
    )
  end

  # Cada turno vira uma mensagem, para a conversa se ler como conversa. O que o
  # cliente falou entra como recebida; o que o bot respondeu, como enviada.
  def record_transcript(conversation)
    Array(@params[:transcript]).each do |turn|
      content = turn[:content].to_s.strip
      next if content.blank?

      conversation.messages.create!(
        account: account,
        inbox: inbox,
        message_type: turn[:role] == 'assistant' ? :outgoing : :incoming,
        content: content
      )
    end
  end

  def record_summary(conversation)
    summary = @params[:summary].to_s.strip
    return if summary.blank?

    conversation.messages.create!(
      account: account,
      inbox: inbox,
      message_type: :outgoing,
      private: true,
      content: summary
    )
  end

  def update_call(conversation)
    TwilioVoiceCall.find_by(call_sid: @params[:call_sid])&.update(
      status: 'completed',
      duration_seconds: @params[:duration_seconds],
      conversation_id: conversation.id
    )
  end
end
