# API que o serviço de mídia (cortexgen-voice) consome. Não é o Twilio quem
# chama aqui, então não há assinatura HMAC para verificar — a autenticação é um
# segredo compartilhado, gravado em Super Admin → Settings → Voice Agent e no
# env do serviço.
class VoiceAgent::BaseController < ApplicationController
  before_action :authenticate_service

  private

  def authenticate_service
    expected = GlobalConfigService.load('VOICE_SERVICE_TOKEN', nil).to_s
    presented = request.headers['Authorization'].to_s.delete_prefix('Bearer ')
    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(presented, expected)

    head :unauthorized
  end
end
