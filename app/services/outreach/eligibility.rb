# Quem pode receber. Roda na preparação da lista e de novo imediatamente antes
# de cada envio: entre uma e outra podem passar horas, e a pessoa pode ter
# pedido para parar. O motivo é um código (`opt_out`, `suppressed`...), que a
# tela traduz. nil = pode.
#
# `reason` lembra os telefones já aprovados nesta instância: duas linhas com o
# mesmo número são uma pessoa só, e vale a primeira. Na hora do envio
# (`at_send`) não vale o veto de "já em outra campanha": duas campanhas vivas
# com a mesma pessoa se vetariam uma à outra e nenhuma mandaria.
class Outreach::Eligibility
  RECENT_DAYS = 30

  def initialize(campaign, recipients, at_send: false)
    @campaign = campaign
    @phones = recipients.map(&:phone).uniq
    @at_send = at_send
    @seen = Set.new
  end

  def reason(recipient)
    found = individual_reason(recipient) || campaign_reason(recipient)
    @seen.add(recipient.phone) unless found
    found
  end

  private

  def individual_reason(recipient)
    return 'no_phone' if recipient.phone.blank?
    return 'invalid_phone' unless recipient.phone.match?(Outreach::Phone::E164)
    return 'opt_out' if blocked.include?(recipient.phone)
    return 'suppressed' if suppressed.include?(recipient.phone)

    'active_conversation' if with_team.include?(recipient.phone)
  end

  def campaign_reason(recipient)
    return 'in_other_campaign' if !@at_send && in_other_campaign.include?(recipient.phone)
    return 'recently_contacted' if recently_contacted.include?(recipient.phone)
    return 'duplicate' if @seen.include?(recipient.phone)

    'missing_variable' if Outreach::Message.new(@campaign, recipient).missing.any?
  end

  def blocked
    @blocked ||= @campaign.account.contacts.where(phone_number: @phones, blocked: true).pluck(:phone_number).to_set
  end

  def suppressed
    @suppressed ||= @campaign.account.outreach_suppressions.where(phone: @phones).pluck(:phone).to_set
  end

  # Conversa aberta com uma pessoa da equipe: a campanha não interrompe atendimento.
  def with_team
    @with_team ||= Conversation.where(inbox_id: @campaign.inbox_id, status: [:open, :pending]).where.not(assignee_id: nil)
                               .joins(:contact).where(contacts: { phone_number: @phones }).pluck('contacts.phone_number').to_set
  end

  def in_other_campaign
    live = Outreach::Campaign.where(status: Outreach::Campaign::LIVE_STATUSES)
    @in_other_campaign ||= others.where(status: :pending).merge(live).pluck(:phone).to_set
  end

  def recently_contacted
    @recently_contacted ||= others.where(sent_at: RECENT_DAYS.days.ago..).pluck(:phone).to_set
  end

  def others
    @campaign.account.outreach_recipients.joins(:campaign).where(phone: @phones).where.not(campaign_id: @campaign.id)
  end
end
