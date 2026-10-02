# Mensagem ao cliente sobre um compromisso (lembrete, falta), pela conversa
# dele no WhatsApp por QR (OpenWA): a do compromisso ou a mais recente do
# contato num número por QR. No WhatsApp oficial, fora da janela de 24 h, só
# template aprovado passa: fica de fora até existir um.
#
# Marcadores: {name} (primeiro nome), {date}, {time} (no fuso de quem atende),
# {type} e {link} (o Google Meet, ou o local).
class Agenda::CustomerMessage
  def initialize(appointment, template)
    @appointment = appointment
    @template = template
  end

  # false quando não há como mandar (sem conversa por QR, contato bloqueado).
  def deliver
    conversation = qr_conversation
    return false if conversation.nil? || @appointment.contact.blocked?

    # Sem remetente, como as mensagens de campanha: uma resposta de agente numa
    # conversa pendente a tiraria do bot.
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id,
                                  message_type: :outgoing, content: text)
    true
  end

  def text
    local = @appointment.starts_at.in_time_zone(zone)
    @template.gsub('{name}', @appointment.contact.name.to_s.split.first.to_s)
             .gsub('{date}', local.strftime('%d/%m'))
             .gsub('{time}', local.strftime('%H:%M'))
             .gsub('{type}', @appointment.event_type&.name.to_s)
             .gsub('{link}', (@appointment.meeting_url.presence || @appointment.location).to_s)
  end

  private

  def zone
    ::Agenda::Availability.find_by(account_id: @appointment.account_id, user_id: @appointment.owner_id)&.zone || Time.zone
  end

  def qr_conversation
    conversation = @appointment.conversation
    return conversation if conversation && qr_inbox?(conversation.inbox)

    @appointment.contact.conversations.includes(inbox: :channel).order(last_activity_at: :desc)
                .find { |candidate| qr_inbox?(candidate.inbox) }
  end

  def qr_inbox?(inbox)
    inbox.channel_type == 'Channel::Api' && inbox.channel.webhook_url.to_s.include?('/chatwoot-adapter/')
  end
end
