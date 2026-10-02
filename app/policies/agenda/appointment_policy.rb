# Todo mundo da conta vê a agenda da equipe e marca compromissos; apagar é de
# quem criou, do responsável ou de um admin.
class Agenda::AppointmentPolicy < ApplicationPolicy
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
    @account_user.administrator? || [record.created_by_id, record.owner_id].include?(@user.id)
  end
end
