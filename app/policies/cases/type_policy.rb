# Tipos de caso: todos da conta leem (para abrir casos); só admin configura.
class Cases::TypePolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
