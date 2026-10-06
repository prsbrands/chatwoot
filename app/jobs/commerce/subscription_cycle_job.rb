# Cobrança assistida das assinaturas sem débito automático (Yappy), a cada 5 min
# no TriggerScheduledItemsJob: a fatura do ciclo seguinte sai RENEWAL_NOTICE
# antes do vencimento, com o link pela conversa e pelo e-mail; no dia do
# vencimento vai um lembrete pela conversa; OVERDUE_AFTER sem pagamento, a
# assinatura fica em atraso. Pagar a fatura (Commerce::DocumentFlow) ativa e
# avança o período.
class Commerce::SubscriptionCycleJob < ApplicationJob
  queue_as :scheduled_jobs

  RENEWAL_NOTICE = 3.days
  OVERDUE_AFTER = 5.days

  def perform
    assisted = Commerce::Subscription.joins(:provider).where(commerce_payment_providers: { provider: Commerce::Subscription::ASSISTED })
    assisted.where(status: :active, cancel_at_period_end: false, current_period_end: ..RENEWAL_NOTICE.from_now).find_each do |subscription|
      next if subscription.invoices.exists?(period_start: subscription.current_period_end.to_date)

      Commerce::SubscriptionBilling.new(subscription).issue_renewal!
    end
    assisted.where(status: %i[active past_due]).find_each { |subscription| follow_up(subscription) }
  end

  private

  def follow_up(subscription)
    billing = Commerce::SubscriptionBilling.new(subscription)
    invoice = billing.open_invoice
    return unless invoice&.due_date

    billing.remind!(invoice) if invoice.due_date == Date.current && invoice.details['reminded_on'].blank?
    billing.overdue!(invoice) if subscription.active? && invoice.due_date <= OVERDUE_AFTER.ago.to_date
  end
end
