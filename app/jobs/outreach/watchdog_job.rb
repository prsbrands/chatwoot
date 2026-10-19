# A cada 5 minutos (TriggerScheduledItemsJob): religa a cadeia de envio que
# morreu (reinício do sidekiq no meio da espera), marca como falha o envio que
# ficou em andamento sem resposta (nunca é repetido: pode ter saído) e pausa a
# campanha cujo número perdeu a sessão.
class Outreach::WatchdogJob < ApplicationJob
  queue_as :scheduled_jobs

  STUCK_AFTER = 10.minutes
  DEAD_AFTER = 2.minutes

  def perform
    Outreach::Campaign.running.includes(inbox: :channel).find_each do |campaign|
      fail_stuck(campaign)
      if campaign.inbox.channel.reauthorization_required?
        campaign.transition_to!(:paused, paused_at: Time.current, paused_reason: 'session_down')
      elsif campaign.wake_at.nil? || campaign.wake_at < DEAD_AFTER.ago
        campaign.schedule_wake!(Time.current)
      end
    end
  end

  private

  # Envio em andamento há tempo demais: não se sabe se saiu, então não se repete.
  def fail_stuck(campaign)
    stuck = campaign.recipients.sending.where(updated_at: ..STUCK_AFTER.ago)
    stuck.update_all(status: Outreach::Recipient.statuses[:failed], error: 'send interrupted; not retried') # rubocop:disable Rails/SkipsModelValidations
  end
end
