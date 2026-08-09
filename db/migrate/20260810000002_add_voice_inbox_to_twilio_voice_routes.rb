class AddVoiceInboxToTwilioVoiceRoutes < ActiveRecord::Migration[7.1]
  def change
    # A inbox onde as chamadas deste número viram conversa. Nasce na primeira
    # chamada e fica gravada aqui, para o painel mostrar qual é e o operador
    # poder trocá-la em Settings → Inboxes sem depender de convenção de nome.
    add_column :twilio_voice_routes, :voice_inbox_id, :bigint

    # Duração e transcrição do que aconteceu, para a tela de chamadas e para o
    # custo por minuto da Fase 4.
    add_column :twilio_voice_calls, :duration_seconds, :integer
    add_column :twilio_voice_calls, :conversation_id, :bigint
  end
end
