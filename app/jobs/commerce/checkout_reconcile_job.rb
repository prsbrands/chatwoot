# Conciliação das tentativas de pagamento online que ainda não tiveram resposta
# (webhook atrasado ou perdido): pergunta ao provedor a cada 5 min
# (TriggerScheduledItemsJob). Passado o prazo sem pagamento, a tentativa expira.
class Commerce::CheckoutReconcileJob < ApplicationJob
  queue_as :scheduled_jobs

  GRACE = 2.minutes

  def perform
    Commerce::Checkout.pending.where(created_at: ...GRACE.ago).includes(:provider).find_each do |checkout|
      next checkout.update!(status: :expired) if checkout.external_id.blank?

      Commerce::CheckoutSettler.new(checkout).refresh!
    rescue Commerce::Gateways::Error => e
      Rails.logger.warn("[COMMERCE] checkout #{checkout.id} not reconciled: #{e.message}")
    end
  end
end
