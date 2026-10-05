# Comercial: todos da conta consultam (o agente cota e fatura com o catálogo);
# só admin cadastra e altera.
class Commerce::BasePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
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
