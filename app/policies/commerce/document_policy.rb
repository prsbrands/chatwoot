# Orçamentos e faturas: toda a equipe cria, edita, gera e envia (vender é do dia
# a dia do agente); apagar rascunho, anular e mexer em pagamento é do admin.
class Commerce::DocumentPolicy < Commerce::BasePolicy
  %i[create? update? pdf? deliver? accept? decline? to_invoice? reopen? archive? unarchive? review_count?].each do |action|
    define_method(action) { true }
  end

  def void?
    @account_user.administrator?
  end

  def add_payment?
    @account_user.administrator?
  end

  def remove_payment?
    @account_user.administrator?
  end

  def issue_receipt?
    @account_user.administrator?
  end
end
