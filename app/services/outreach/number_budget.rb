# O que o número aguenta por dia. O teto sobe com a idade do número (20 / 50 /
# 100 / 200, a mesma tabela do follow-up) e a lista fria pode usar só metade
# dele: quem nunca falou com a empresa é o padrão que o WhatsApp bane. O teto
# conta os envios de todas as campanhas do número, no dia do fuso da inbox.
class Outreach::NumberBudget
  TIERS = [[3, 20], [7, 50], [14, 100]].freeze
  TOP_CAP = 200
  COLD_SHARE = 0.5
  ACTIVATED_CACHE = 10.minutes

  def initialize(inbox)
    @inbox = inbox
  end

  def zone
    @inbox.timezone
  end

  def daily_cap(now)
    age_days = (now - activated_at) / 1.day
    TIERS.find { |days, _cap| age_days <= days }&.last || TOP_CAP
  end

  # Quantos envios ainda cabem hoje para uma campanha fria ou não.
  def allowance(now, cold:)
    day = now.in_time_zone(zone).all_day
    cap = daily_cap(now)
    left = cap - sent_in(day)
    return left unless cold

    [left, (cap * COLD_SHARE).floor - sent_in(day, cold: true)].min
  end

  # O último envio do número, de qualquer campanha.
  def last_sent_at
    Outreach::Recipient.joins(:campaign).where(outreach_campaigns: { inbox_id: @inbox.id }).maximum(:sent_at)
  end

  private

  # Quando o número começou a falar: o botlayer guarda na rota da inbox. Sem a
  # rota, vale a criação da inbox.
  def activated_at
    stamp = Rails.cache.fetch("outreach:activated_at:#{@inbox.id}", expires_in: ACTIVATED_CACHE) do
      (route_activated_at || @inbox.created_at).iso8601
    end
    Time.zone.parse(stamp)
  end

  def route_activated_at
    return unless Integrations::Botlayer::Client.configured?

    route = Integrations::Botlayer::Client.new.routes(@inbox.account_id).find { |item| item['chatwoot_inbox_id'] == @inbox.id }
    route&.dig('number_activated_at')
  end

  def sent_in(range, cold: nil)
    scope = Outreach::Recipient.joins(:campaign).where(outreach_campaigns: { inbox_id: @inbox.id }).where(sent_at: range)
    scope = scope.where(outreach_campaigns: { cold: cold }) unless cold.nil?
    scope.count
  end
end
