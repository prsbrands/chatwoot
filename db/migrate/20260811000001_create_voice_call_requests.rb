# O registro de quem pediu uma ligação de demo pelo formulário público do
# site. Existe por dois motivos que não são o mesmo: é o registro de
# consentimento exigido para ligar com voz automatizada/IA, e é a fonte que
# o limite por telefone consulta para não discar duas vezes pro mesmo número
# na mesma janela.
class CreateVoiceCallRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :voice_call_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :twilio_voice_route, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone_number, null: false
      t.string :normalized_phone_number
      t.datetime :consent_given_at
      t.string :ip_address, null: false
      t.string :user_agent
      t.string :status, null: false, default: 'pending'
      t.string :rejection_reason
      t.string :call_sid

      t.timestamps
    end
    add_index :voice_call_requests, :normalized_phone_number
    add_index :voice_call_requests, :created_at
  end
end
