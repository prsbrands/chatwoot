class CreateTwilioCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :twilio_credentials do |t|
      t.references :account, null: false, index: { unique: true }, foreign_key: true
      t.string :account_sid, null: false
      t.string :auth_token, null: false

      t.timestamps
    end
  end
end
