# Teto mensal de gasto com IA da conta (bot_account_settings.ai_monthly_budget_usd,
# db/botlayer/bot_ai_usage.sql). Só o Super Admin define; em branco = sem teto.
# O Guard e o follow-up do n8n leem o teto a cada mensagem.
class SuperAdmin::AiBudgetsController < SuperAdmin::ApplicationController
  def update
    account = Account.find(params[:account_id])
    Integrations::Botlayer::Client.new.upsert_account_settings(account.id, { ai_monthly_budget_usd: budget })
    redirect_to super_admin_account_path(account), notice: I18n.t('super_admin.ai_budget.saved')
  end

  private

  def budget
    value = params.require(:ai_budget).fetch(:monthly_usd, '').to_s.strip
    return nil if value.empty?

    BigDecimal(value).tap { |usd| raise ArgumentError if usd.negative? }
  rescue ArgumentError
    raise ActionController::BadRequest, 'invalid monthly_usd'
  end
end
