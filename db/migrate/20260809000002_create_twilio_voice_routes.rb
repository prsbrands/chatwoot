class CreateTwilioVoiceRoutes < ActiveRecord::Migration[7.1]
  def change
    create_table :twilio_voice_routes do |t|
      t.references :account, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.string :destination_type, null: false
      t.string :destination, null: false
      t.integer :ring_timeout, null: false, default: 20
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
    add_index :twilio_voice_routes, [:account_id, :phone_number], unique: true

    create_table :twilio_voice_calls do |t|
      t.references :account, null: false, foreign_key: true
      t.string :call_sid, null: false
      t.string :phone_number, null: false
      t.string :from_number
      t.string :status, null: false, default: 'ringing'

      t.timestamps
    end
    add_index :twilio_voice_calls, :call_sid, unique: true
  end
end
