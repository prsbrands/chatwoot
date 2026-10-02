# Agenda, 3ª parte: o tipo que a IA pode oferecer na conversa e o lembrete ao
# cliente (minutos antes e o texto, com {name}, {date}, {time} e {type}).
class AddAiBookingAndRemindersToAgenda < ActiveRecord::Migration[7.1]
  def change
    add_column :agenda_event_types, :ai_bookable, :boolean, null: false, default: false
    add_column :agenda_event_types, :reminder_minutes_before, :integer
    add_column :agenda_event_types, :reminder_message, :text
    add_column :agenda_appointments, :reminder_sent_at, :datetime
  end
end
