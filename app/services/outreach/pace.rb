# Pode mandar agora? Devolve nil, ou o motivo da espera e quando tentar de novo.
# Ritmo é espera, nunca falha: a pessoa continua pendente e a cadeia acorda no
# horário dado. O mais restritivo entre a campanha e o número sempre vale.
class Outreach::Pace
  Wait = Struct.new(:reason, :until)
  HOURLY_RETRY = 10.minutes

  def initialize(campaign, budget: Outreach::NumberBudget.new(campaign.inbox))
    @campaign = campaign
    @pacing = campaign.pace
    @budget = budget
  end

  def wait(now = Time.current)
    local = now.in_time_zone(@budget.zone)
    return Wait.new(:outside_window, opening_after(local)) unless open?(local)

    gap_wait(now) || cap_wait(now, local)
  end

  private

  def gap_wait(now)
    return Wait.new(:interval, @campaign.next_send_at) if @campaign.next_send_at.present? && @campaign.next_send_at > now

    gap = number_gap(now)
    Wait.new(:interval, gap) if gap
  end

  def cap_wait(now, local)
    return Wait.new(:hourly_cap, now + HOURLY_RETRY) if sent_in((now - 1.hour)..now) >= @pacing.max_per_hour
    return Wait.new(:daily_cap, opening_after(local.end_of_day)) if daily_cap_reached?(local)

    Wait.new(:number_cap, opening_after(local.end_of_day)) unless @budget.allowance(now, cold: @campaign.cold).positive?
  end

  # Duas campanhas no mesmo número também respeitam o intervalo mínimo entre si.
  def number_gap(now)
    last = @budget.last_sent_at
    return unless last

    ready_at = last + @pacing.interval_min.seconds
    ready_at if ready_at > now
  end

  def open?(local)
    @pacing.days.include?(local.wday) && local.hour >= @pacing.window_start && local.hour < @pacing.window_end
  end

  # A próxima abertura da janela, num dia permitido, depois de `from`.
  def opening_after(from)
    (0..7).each do |offset|
      opening = (from.beginning_of_day + offset.days).change(hour: @pacing.window_start)
      return opening if opening > from && @pacing.days.include?(opening.wday)
    end
  end

  def daily_cap_reached?(local)
    @pacing.max_per_day.present? && sent_in(local.all_day) >= @pacing.max_per_day
  end

  def sent_in(range)
    @campaign.recipients.where(sent_at: range).count
  end
end
