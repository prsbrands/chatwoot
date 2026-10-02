# Agentes e admins criam, editam e concluem tarefas; apagar é de quem criou ou
# de um admin.
class Sales::TaskPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    @account_user.administrator? || record.created_by_id == @user.id
  end
end
