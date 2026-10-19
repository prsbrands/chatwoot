# Classifica a lista inteira e deixa a campanha pronta para iniciar: cada pessoa
# fica `pending` (pode receber) ou `excluded` com o motivo. Quem a equipe tirou à
# mão (`manual`) continua tirado. Devolve a contagem por motivo, que a tela
# mostra antes de o admin confirmar o início.
class Outreach::Prepare
  def initialize(campaign)
    @campaign = campaign
  end

  def perform
    @campaign.transition_to!(:draft) if @campaign.ready?
    recipients = @campaign.recipients.where(status: [:pending, :excluded]).order(:id).reject { |recipient| recipient.excluded_reason == 'manual' }
    eligibility = Outreach::Eligibility.new(@campaign, recipients)
    by_reason = recipients.group_by { |recipient| eligibility.reason(recipient) }
    by_reason.each { |reason, group| mark(group.map(&:id), reason) }
    @campaign.transition_to!(:ready)
    by_reason.transform_values(&:size)
  end

  private

  def mark(ids, reason)
    status = Outreach::Recipient.statuses[reason ? :excluded : :pending]
    ids.each_slice(1000) do |slice|
      @campaign.recipients.where(id: slice).update_all(status: status, excluded_reason: reason) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
