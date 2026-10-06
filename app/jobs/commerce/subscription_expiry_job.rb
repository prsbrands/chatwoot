# Encerra as assinaturas canceladas para o fim do período quando ele chega (a
# cada 5 min, no TriggerScheduledItemsJob). O Mercado Pago para de cobrar na
# hora do cancelamento e não avisa no fim; no Stripe, vale se o aviso de fim se
# perder.
class Commerce::SubscriptionExpiryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Commerce::Subscription.where(cancel_at_period_end: true, current_period_end: ...Time.current).where.not(status: :canceled)
                          .find_each { |subscription| Commerce::SubscriptionBilling.new(subscription).ended! }
  end
end
