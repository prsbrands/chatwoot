# Agenda: compromissos com hora marcada e a conexão de cada pessoa com o
# Google Calendar (um app OAuth por instalação, uma conta Google por pessoa e
# conta do Chatwoot).
class CreateAgenda < ActiveRecord::Migration[7.1]
  def change
    create_appointments
    create_google_connections
  end

  private

  def create_appointments
    create_table :agenda_appointments do |t|
      t.references :account, null: false, index: false
      t.string :title, null: false
      t.text :notes
      t.string :location
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # pending | confirmed | cancelled | completed | no_show
      t.integer :status, null: false, default: 1
      t.references :owner, index: true
      t.references :contact, index: true
      t.references :deal, index: true
      t.references :conversation, index: false
      t.bigint :created_by_id
      t.string :cancellation_reason
      t.timestamps
    end
    add_index :agenda_appointments, [:account_id, :starts_at]
    add_google_sync_columns
  end

  # Evento no Google do responsável, quando ele tem a agenda conectada.
  def add_google_sync_columns
    add_column :agenda_appointments, :google_event_id, :string
    add_column :agenda_appointments, :google_connection_id, :bigint
    add_column :agenda_appointments, :google_synced_at, :datetime
    add_column :agenda_appointments, :google_sync_error, :string
  end

  def create_google_connections
    create_table :agenda_google_connections do |t|
      t.references :account, null: false, index: false
      t.references :user, null: false, index: true
      t.string :email, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      # healthy | reauthorization_required
      t.integer :status, null: false, default: 0
      t.string :last_error
      t.timestamps
    end
    add_index :agenda_google_connections, [:account_id, :user_id], unique: true
  end
end
