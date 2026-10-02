# Lembrete ao cliente antes do compromisso (Agenda::CustomerMessage, por ora só
# no WhatsApp por QR). Roda a cada 5 min (TriggerScheduledItemsJob).
class Agenda::ReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  HORIZON = 7.days

  def perform
    due.find_each do |appointment|
      next if appointment.starts_at - appointment.event_type.reminder_minutes_before.minutes > Time.current
      next unless ::Agenda::CustomerMessage.new(appointment, appointment.event_type.reminder_message).deliver

      appointment.update_column(:reminder_sent_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  private

  def due
    ::Agenda::Appointment.confirmed.where(reminder_sent_at: nil, starts_at: Time.current..HORIZON.from_now)
                         .where.not(contact_id: nil)
                         .joins(:event_type).where.not(agenda_event_types: { reminder_minutes_before: nil })
                         .preload(:event_type, :contact, :owner, conversation: { inbox: :channel })
  end
end
