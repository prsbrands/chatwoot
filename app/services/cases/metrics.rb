# Fase 3: os números dos casos no período (últimos `days` dias) e a foto de
# agora, no total, por tipo e por responsável. "No prazo" é resolvido até o
# prazo; caso sem prazo fica fora dessa conta. Tempo até resolver em horas
# corridas, da abertura à resolução (a pausa esperando o cliente conta).
class Cases::Metrics
  def initialize(account, days:)
    @account = account
    @days = days
    @since = days.days.ago
  end

  def to_h
    { days: @days, summary: numbers(cases), by_type: by_type, by_assignee: by_assignee }
  end

  private

  # Os casos que contam: abertos ou resolvidos no período, e os ativos agora.
  def cases
    @cases ||= @account.cases.includes(:type, :assignee)
                       .where('cases_cases.created_at >= :since OR cases_cases.resolved_at >= :since', since: @since)
                       .or(@account.cases.includes(:type, :assignee).active).to_a
  end

  def numbers(list)
    opened = list.select { |kase| in_period?(kase.created_at) }
    resolved = list.select { |kase| in_period?(kase.resolved_at) }
    {
      opened: opened.size,
      opened_by_ai: opened.count(&:source_ai?),
      resolved: resolved.size,
      canceled: list.count { |kase| in_period?(kase.canceled_at) },
      avg_resolution_hours: average_hours(resolved),
      on_time_rate: on_time_rate(resolved),
      active: list.count(&:active?),
      overdue: list.count(&:overdue?)
    }
  end

  def in_period?(time)
    time.present? && time >= @since
  end

  def on_time_rate(resolved)
    with_due = resolved.select(&:due_at)
    return nil if with_due.empty?

    (with_due.count { |kase| kase.resolved_at <= kase.due_at }.to_f / with_due.size).round(2)
  end

  def average_hours(resolved)
    return nil if resolved.empty?

    (resolved.sum { |kase| kase.resolved_at - kase.created_at } / resolved.size / 3600.0).round(1)
  end

  def by_type
    cases.group_by(&:type).sort_by { |type, _| [type.position, type.id] }
         .map { |type, list| { id: type.id, name: type.name, color: type.color }.merge(numbers(list)) }
  end

  def by_assignee
    cases.group_by(&:assignee).sort_by { |user, _| user&.available_name.to_s }
         .map { |user, list| { id: user&.id, name: user&.available_name }.merge(numbers(list)) }
  end
end
