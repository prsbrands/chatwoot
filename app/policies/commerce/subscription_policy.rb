# Assinaturas: toda a equipe cria e envia o link (vender é do dia a dia do
# agente); cancelar é do admin.
class Commerce::SubscriptionPolicy < Commerce::BasePolicy
  def create?
    true
  end

  def deliver?
    true
  end

  def cancel?
    @account_user.administrator?
  end
end
