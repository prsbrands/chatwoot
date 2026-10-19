# A lista a partir do CRM: contatos com uma etiqueta, numa etapa do funil ou com
# conversa numa caixa. Os filtros somam (todos precisam valer). Contato sem
# telefone entra e sai na preparação com o motivo, para a equipe ver quantos
# faltam.
class Outreach::Audience
  def initialize(campaign, filters)
    @campaign = campaign
    @filters = filters
  end

  def perform
    scope = contacts
    if scope.count > Outreach::Sheet::MAX_ROWS
      @campaign.errors.add(:audience, "has more than #{Outreach::Sheet::MAX_ROWS} contacts")
      raise ActiveRecord::RecordInvalid, @campaign
    end

    rows = scope.pluck(:id, :name, :phone_number).map { |id, name, phone| attributes(id, name, phone) }
    Outreach::Recipient.transaction do
      @campaign.recipients.delete_all
      rows.each_slice(1000) { |slice| Outreach::Recipient.insert_all(slice) } # rubocop:disable Rails/SkipsModelValidations
      @campaign.update!(audience: { 'source' => 'crm', 'filters' => @filters, 'count' => rows.size })
    end
    rows.size
  end

  private

  def contacts
    scope = @campaign.account.contacts
    scope = scope.tagged_with(@filters['label']) if @filters['label'].present?
    scope = scope.where(id: in_stage) if @filters['stage_id'].present?
    scope = scope.where(id: ContactInbox.where(inbox_id: @filters['inbox_id']).select(:contact_id)) if @filters['inbox_id'].present?
    scope.order(:id)
  end

  def in_stage
    Sales::Deal.where(account_id: @campaign.account_id, stage_id: @filters['stage_id']).select(:contact_id)
  end

  def attributes(id, name, phone)
    { account_id: @campaign.account_id, campaign_id: @campaign.id, phone: phone.to_s, name: name.presence, contact_id: id }
  end
end
