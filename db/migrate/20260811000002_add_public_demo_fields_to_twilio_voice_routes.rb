# Cada país novo (Panamá, Colômbia, Estados Unidos, e agora o Brasil) tem seu
# próprio número e sua própria persona de demo — ligar do número certo pro
# DDI de quem atende é o que já resolvia a taxa de resposta do Panamá (ver
# HANDOFF, "identificador de chamada"). Em vez de um par fixo no `.env` que
# exige deploy pra cada país novo, cada rota declara o DDI e a persona que
# atende na demo pública, e o serviço escolhe pelo telefone digitado no site.
class AddPublicDemoFieldsToTwilioVoiceRoutes < ActiveRecord::Migration[7.1]
  def change
    add_column :twilio_voice_routes, :public_demo_dial_code, :string
    add_column :twilio_voice_routes, :public_demo_persona_slug, :string
    add_index :twilio_voice_routes, :public_demo_dial_code, unique: true, where: 'public_demo_dial_code IS NOT NULL'
  end
end
