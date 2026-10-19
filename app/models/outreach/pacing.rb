# O ritmo de uma campanha por QR: janela de horário e dias, intervalo aleatório
# entre envios, tetos por hora e por dia, e o lote com pausa ("10 envios, e
# descansa uns minutos"), que é o ritmo de uma pessoa e não de um robô. A
# campanha só pode ser mais lenta que o número (Outreach::NumberBudget), nunca
# mais rápida. Os campos ausentes herdam o padrão.
class Outreach::Pacing
  INTERVAL_FLOOR = 15
  DEFAULTS = {
    window_start: 8,
    window_end: 20,
    days: [1, 2, 3, 4, 5, 6],
    interval_min: 20,
    interval_max: 45,
    max_per_hour: 30,
    max_per_day: nil,
    batch_size: 10,
    batch_pause_min: 5,
    batch_pause_max: 15
  }.freeze

  DEFAULTS.each_key { |key| define_method(key) { @values[key] } }

  CHECKS = %w[window days interval max_per_hour max_per_day batch].freeze

  # O que está fora do aceitável, para a validação da campanha.
  def self.errors(raw)
    new(raw).errors
  end

  def initialize(raw)
    @values = DEFAULTS.merge((raw || {}).to_h.symbolize_keys.slice(*DEFAULTS.keys))
  end

  def to_h
    @values.dup
  end

  # Segundos até o próximo envio.
  def next_interval
    rand(interval_min..interval_max)
  end

  # Segundos de descanso entre dois lotes.
  def next_batch_pause
    rand(batch_pause_min..batch_pause_max) * 60
  end

  def well_typed?
    integers = DEFAULTS.keys - [:days, :max_per_day]
    integers.all? { |key| @values[key].is_a?(Integer) } &&
      (max_per_day.nil? || max_per_day.is_a?(Integer)) &&
      days.is_a?(Array) && days.all?(Integer)
  end

  def errors
    return ['type'] unless well_typed?

    CHECKS.select { |check| send("#{check}_invalid?") }
  end

  private

  def window_invalid?
    !(window_start.between?(0, 23) && window_end.between?(1, 24) && window_start < window_end)
  end

  def days_invalid?
    days.empty? || !(days - (0..6).to_a).empty?
  end

  def interval_invalid?
    interval_min < INTERVAL_FLOOR || interval_min > interval_max
  end

  def max_per_hour_invalid?
    !max_per_hour.between?(1, 120)
  end

  def max_per_day_invalid?
    !(max_per_day.nil? || max_per_day.between?(1, 1000))
  end

  def batch_invalid?
    !(batch_size.between?(1, 50) && batch_pause_min.between?(1, 120) && batch_pause_min <= batch_pause_max)
  end
end
