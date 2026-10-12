# Agentes e admins abrem e trabalham os casos; apagar é só do admin (o caso
# errado se cancela).
class Cases::CasePolicy < ApplicationPolicy
  %i[index? show? create? update? overdue_count? start? wait_customer? resolve? cancel? reopen? note? link_conversation?].each do |action|
    define_method(action) { true }
  end

  def destroy?
    @account_user.administrator?
  end
end
