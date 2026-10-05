# Orçamentos e faturas: toda a equipe cria, edita, gera e envia (vender é do dia
# a dia do agente); apagar rascunho, anular e mexer em pagamento é do admin.
class Commerce::DocumentPolicy < Commerce::BasePolicy
  %i[create? update? pdf? deliver? accept? decline? to_invoice?].each { |action| define_method(action) { true } }

  def void?
    @account_user.administrator?
  end

  def add_payment?
    @account_user.administrator?
  end

  def remove_payment?
    @account_user.administrator?
  end
end
