class AddMetricsToTwilioVoiceCalls < ActiveRecord::Migration[7.1]
  def change
    # Consumo dos três fornecedores e a espera que quem ligou sentiu. Guardado
    # como jsonb porque a lista cresce conforme aprendemos o que olhar, e
    # nenhuma dessas medidas é consultada em filtro.
    add_column :twilio_voice_calls, :metrics, :jsonb, null: false, default: {}
  end
end
