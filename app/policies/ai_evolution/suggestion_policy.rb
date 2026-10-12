# Evolução da IA: aplicar muda a base e o prompt da persona, então ver, aplicar,
# recusar e desfazer é do admin. O n8n entra com o token de um admin da conta.
class AiEvolution::SuggestionPolicy < ApplicationPolicy
  %i[index? show? update? apply? reject? undo? pending_count? progress? bot?].each do |action|
    define_method(action) { @account_user.administrator? }
  end
end
