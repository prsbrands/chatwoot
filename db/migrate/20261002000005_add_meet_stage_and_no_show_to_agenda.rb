# Agenda, fechando o ciclo: link do Google Meet no evento, a etapa para onde o
# negócio vai quando o compromisso é marcado e a mensagem ao cliente que não
# compareceu.
class AddMeetStageAndNoShowToAgenda < ActiveRecord::Migration[7.1]
  def change
    add_column :agenda_event_types, :google_meet, :boolean, null: false, default: false
    add_column :agenda_event_types, :booked_stage_id, :bigint
    add_column :agenda_event_types, :no_show_message, :text
    add_column :agenda_appointments, :meeting_url, :string
  end
end
