# Todos veem os tipos de agendamento (para marcar); só admin cria e altera.
class Agenda::EventTypePolicy < ApplicationPolicy
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
