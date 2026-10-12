# Agentes e admins abrem e trabalham os casos; apagar é só do admin (o caso
# errado se cancela).
class Cases::CasePolicy < ApplicationPolicy
  %i[index? show? create? update? overdue_count? start? wait_customer? resolve? cancel? reopen? note? link_conversation? relay?
     metrics?].each do |action|
    define_method(action) { true }
  end

  def destroy?
    @account_user.administrator?
  end

  # O n8n entra com o token de um admin da conta (bot_account_settings).
  def bot?
    @account_user.administrator?
  end
end
