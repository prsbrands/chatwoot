# Evolução da IA (flag `ai_evolution`). Dentro deste namespace `AiEvolution` é
# o módulo do controller: os models são sempre `::AiEvolution::...`.
class Api::V1::Accounts::AiEvolution::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_ai_evolution_enabled!

  private

  def ensure_ai_evolution_enabled!
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('ai_evolution')
  end
end
