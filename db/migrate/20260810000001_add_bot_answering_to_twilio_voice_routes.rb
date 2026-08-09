class AddBotAnsweringToTwilioVoiceRoutes < ActiveRecord::Migration[7.1]
  def change
    # Quem atende primeiro. O padrão preserva o comportamento da Fase 2 para as
    # rotas que já existem: toca no humano.
    add_column :twilio_voice_routes, :answer_mode, :string, null: false, default: 'human'
    # O que fazer quando o humano não atende. 'hangup' é o que o controller já
    # fazia — recado curto e desliga.
    add_column :twilio_voice_routes, :no_answer_action, :string, null: false, default: 'hangup'
    add_column :twilio_voice_routes, :bot_persona_slug, :string

    # Quando o bot atende primeiro não existe destino humano para gravar, e
    # gravar string vazia só para satisfazer o NOT NULL esconderia isso de quem
    # ler a tabela depois.
    change_column_null :twilio_voice_routes, :destination, true
  end
end
