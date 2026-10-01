# Agentes veem o funil; so admin cria, edita e apaga funis.
class Sales::PipelinePolicy < ApplicationPolicy
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
