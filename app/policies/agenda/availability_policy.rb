# A jornada é da pessoa: ela mesma ou um admin altera.
class Agenda::AvailabilityPolicy < ApplicationPolicy
  def index?
    true
  end

  def update?
    @account_user.administrator? || record.user_id == @user.id
  end
end
