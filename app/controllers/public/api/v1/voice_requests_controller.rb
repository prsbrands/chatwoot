# Ponto de entrada do formulário público do site (via n8n) para a ligação de
# demo automática. Não tem sessão nem conta — quem chama aqui é confiável
# porque conhece o segredo compartilhado, não porque está logado. O
# visitante nunca fala com este endpoint diretamente: o navegador chama um
# webhook do n8n, e é o n8n que carrega o token até aqui.
class Public::Api::V1::VoiceRequestsController < PublicController
  before_action :authenticate_shared_secret

  def create
    request_record = Voice::PublicCallRequestService.new(
      name: params[:name],
      email: params[:email],
      phone_number: params[:phone_number],
      consent: ActiveModel::Type::Boolean.new.cast(params[:consent]),
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    ).perform

    render json: { status: request_record.status, reason: request_record.rejection_reason }
  end

  private

  # Comparação em tempo constante — o `==` normal vaza tempo de execução
  # proporcional ao prefixo que bate, o que dá pra explorar num segredo
  # exposto num endpoint público.
  def authenticate_shared_secret
    expected = "Bearer #{ENV.fetch('PUBLIC_VOICE_REQUEST_TOKEN')}"
    provided = request.headers['Authorization'].to_s
    return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

    render json: { error: 'unauthorized' }, status: :unauthorized
  end
end
