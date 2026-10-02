# Lembrete ao cliente antes do compromisso, pela conversa dele no WhatsApp por
# QR (OpenWA). Roda a cada 5 min (TriggerScheduledItemsJob). No WhatsApp
# oficial, fora da janela de 24 h, só template aprovado passa: por isso fica de
# fora até existir um template de lembrete.
class Agenda::ReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  HORIZON = 7.days

  def perform
    due.find_each do |appointment|
      next if appointment.starts_at - appointment.event_type.reminder_minutes_before.minutes > Time.current

      conversation = qr_conversation(appointment)
      remind(appointment, conversation) if conversation && !appointment.contact.blocked?
    end
  end

  private

  def due
    ::Agenda::Appointment.confirmed.where(reminder_sent_at: nil, starts_at: Time.current..HORIZON.from_now)
                         .where.not(contact_id: nil)
                         .joins(:event_type).where.not(agenda_event_types: { reminder_minutes_before: nil })
                         .preload(:event_type, :contact, :owner, conversation: { inbox: :channel })
  end

  # A conversa do compromisso, ou a mais recente do contato num número por QR.
  def qr_conversation(appointment)
    return appointment.conversation if appointment.conversation && qr_inbox?(appointment.conversation.inbox)

    appointment.contact.conversations.includes(inbox: :channel).order(last_activity_at: :desc)
               .find { |conversation| qr_inbox?(conversation.inbox) }
  end

  def qr_inbox?(inbox)
    inbox.channel_type == 'Channel::Api' && inbox.channel.webhook_url.to_s.include?('/chatwoot-adapter/')
  end

  # Sem remetente, como as mensagens de campanha: uma resposta de agente numa
  # conversa pendente a tiraria do bot.
  def remind(appointment, conversation)
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id,
                                  message_type: :outgoing, content: reminder_text(appointment))
    appointment.update_column(:reminder_sent_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def reminder_text(appointment)
    zone = ::Agenda::Availability.find_by(account_id: appointment.account_id, user_id: appointment.owner_id)&.zone || Time.zone
    local = appointment.starts_at.in_time_zone(zone)
    appointment.event_type.reminder_message
               .gsub('{name}', appointment.contact.name.to_s.split.first.to_s)
               .gsub('{date}', local.strftime('%d/%m'))
               .gsub('{time}', local.strftime('%H:%M'))
               .gsub('{type}', appointment.event_type.name)
  end
end
