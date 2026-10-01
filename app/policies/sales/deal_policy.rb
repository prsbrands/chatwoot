# Agentes e admins abrem, editam e movem negocios; so admin apaga.
class Sales::DealPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    @account_user.administrator?
  end
end
