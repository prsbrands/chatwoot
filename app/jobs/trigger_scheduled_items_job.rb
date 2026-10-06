class TriggerScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # trigger the scheduled campaign jobs
    Campaign.where(campaign_type: :one_off,
                   campaign_status: :active).where(scheduled_at: 3.days.ago..Time.current).all.find_each(batch_size: 100) do |campaign|
      Campaigns::TriggerOneoffCampaignJob.perform_later(campaign)
    end

    # Job to reopen snoozed conversations
    Conversations::ReopenSnoozedConversationsJob.perform_later

    # Job to reopen snoozed notifications
    Notification::ReopenSnoozedNotificationsJob.perform_later

    # Job to auto-resolve conversations
    Account::ConversationsResolutionSchedulerJob.perform_later

    # Job to sync whatsapp templates
    Channels::Whatsapp::TemplatesSyncSchedulerJob.perform_later

    # Job to trigger pending executions
    AutomationRules::TriggerPendingExecutionsJob.perform_later

    # Radar de risco e score dos negocios do funil de vendas
    Sales::RiskSweepJob.perform_later

    # Lembretes da Agenda pelo WhatsApp por QR
    Agenda::ReminderJob.perform_later

    # Pagamentos online sem resposta do provedor (Comercial)
    Commerce::CheckoutReconcileJob.perform_later

    # Sessões de WhatsApp por QR (OpenWA) que caíram
    Openwa::SessionWatchJob.perform_later if Integrations::Openwa::Client.configured?
  end
end

TriggerScheduledItemsJob.prepend_mod_with('TriggerScheduledItemsJob')
