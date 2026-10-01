# Score do negocio por formula, nunca por LLM (score-formula.ts do DeskComm):
# base 30, +12 por compromisso (ate 3), -8 por objecao (ate 3), +5 por dado de
# qualificacao (ate 4), recencia pelo risco (+10 / -10 / -20), limitado a 0..100.
# Com menos de 2 sinais de conteudo nao ha score (nil, nunca 0): a recencia
# sozinha nao diz nada sobre o negocio. Os fatores vao por chave, e a tela os
# traduz.
class Sales::ScoreFormula
  BASE = 30
  FACT_THRESHOLD = 0.7
  GROUPS = {
    commitment: { keys: %w[next_step asked_proposal buying_intent], points: 12, max: 3 },
    objection: { keys: %w[price_objection timing_objection competitor_or_doubt], points: -8, max: 3 },
    qualification: { keys: %w[need budget timeline authority], points: 5, max: 4 }
  }.freeze
  RECENCY = { 'on_track' => 10, 'at_risk' => -10, 'critical' => -20 }.freeze
  HOT = 70
  WARM = 40
  HYSTERESIS = 5
  MIN_SIGNALS = 2

  def self.compute(facts:, risk:, previous_band: nil)
    factors = GROUPS.flat_map do |_group, rule|
      rule[:keys].select { |key| facts[key].to_f >= FACT_THRESHOLD }.first(rule[:max]).map { |key| { key: key, points: rule[:points] } }
    end
    return { score: nil, band: nil, factors: [] } if factors.size < MIN_SIGNALS

    factors << { key: "recency_#{risk}", points: RECENCY.fetch(risk.to_s) }
    score = (BASE + factors.sum { |factor| factor[:points] }).clamp(0, 100)
    { score: score, band: band_for(score, previous_band), factors: factors }
  end

  # Folga de 5 pontos para a faixa nao piscar entre duas leituras proximas.
  def self.band_for(score, previous)
    band = if score >= HOT
             'hot'
           elsif score >= WARM
             'warm'
           else
             'cold'
           end
    return band if previous.nil? || previous == band

    limit = { %w[hot warm] => HOT, %w[warm hot] => HOT, %w[warm cold] => WARM, %w[cold warm] => WARM }[[previous, band]]
    return band unless limit

    (score - limit).abs < HYSTERESIS ? previous : band
  end
end
