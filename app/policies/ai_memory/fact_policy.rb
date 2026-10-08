# Agentes e admins veem e editam a memória dos clientes; o que o n8n chama
# (reservar conversas e gravar a memória) é só com o token de admin da conta.
class AiMemory::FactPolicy < ApplicationPolicy
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
    true
  end

  def bot?
    @account_user.administrator?
  end
end
