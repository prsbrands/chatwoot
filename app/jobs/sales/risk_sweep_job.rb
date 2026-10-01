# Radar de risco (bloco 3c), a cada 5 minutos pelo TriggerScheduledItemsJob.
# A ultima interacao real e a ultima mensagem publica do cliente ou para ele,
# em qualquer conversa do contato: nota privada e atividade nao contam (no
# DeskComm, contar o silencio como atividade zerava o relogio).
class Sales::RiskSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.feature_sales_pipeline.find_each do |account|
      deals = account.sales_deals.open.includes(:stage, :insight).to_a
      next if deals.empty?

      activity = Message.joins(:conversation)
                        .where(conversations: { account_id: account.id, contact_id: deals.map(&:contact_id) })
                        .where(message_type: %i[incoming outgoing], private: false)
                        .group('conversations.contact_id').maximum(:created_at)
      deals.each do |deal|
        insight = deal.insight || deal.build_insight(account: account)
        insight.refresh!(last_activity_at: activity[deal.contact_id] || deal.created_at, expected_hours: deal.stage.expected_hours)
      end
    end
  end
end
