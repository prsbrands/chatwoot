# Agenda, 2ª parte: tipos de agendamento (duração, folgas, antecedência e quem
# atende) e a jornada semanal de cada pessoa. Os dois juntos dizem os horários
# livres.
class CreateAgendaEventTypes < ActiveRecord::Migration[7.1]
  def change
    create_event_types
    create_table :agenda_availabilities do |t|
      t.references :account, null: false, index: false
      t.references :user, null: false, index: true
      t.string :time_zone, null: false
      # [{ "day": 1, "start": "09:00", "end": "18:00" }, ...] — day 0 = domingo
      t.jsonb :windows, null: false, default: []
      t.timestamps
    end
    add_index :agenda_availabilities, [:account_id, :user_id], unique: true
    add_reference :agenda_appointments, :event_type, index: false
  end

  private

  def create_event_types
    create_table :agenda_event_types do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.integer :duration_minutes, null: false, default: 60
      t.integer :buffer_before_minutes, null: false, default: 0
      t.integer :buffer_after_minutes, null: false, default: 0
      t.integer :minimum_notice_minutes, null: false, default: 120
      t.integer :booking_window_days, null: false, default: 60
      t.string :location
      t.references :default_owner, index: false
      t.boolean :requires_confirmation, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end
end
