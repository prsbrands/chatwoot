# Credenciais de cobrança: só o admin vê e altera.
class Commerce::PaymentProviderPolicy < Commerce::BasePolicy
  def index?
    @account_user.administrator?
  end
end
