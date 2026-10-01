# Risco e score do negocio (bloco 3c). Escrito pelo Sales::RiskSweepJob e pelo
# Sales::StageAdvisor, nunca pela tela; so grava quando algo mudou.
class Sales::DealInsight < ApplicationRecord
  self.table_name = 'sales_deal_insights'

  belongs_to :account
  belongs_to :deal, class_name: 'Sales::Deal'

  enum :risk, { on_track: 0, at_risk: 1, critical: 2 }

  # Frio = horas esperadas da etapa; critico = 3x isso (risk-radar do DeskComm).
  def self.risk_for(hours_idle, expected_hours)
    return :on_track if hours_idle < expected_hours
    return :critical if hours_idle >= expected_hours * 3

    :at_risk
  end

  def refresh!(last_activity_at:, expected_hours:, now: Time.current)
    new_risk = self.class.risk_for((now - last_activity_at) / 1.hour, expected_hours)
    self.last_activity_at = last_activity_at
    self.risk_since = new_risk == :on_track ? nil : (risk == new_risk.to_s && risk_since) || now
    self.risk = new_risk
    apply_score
    save! if changed?
  end

  def record_facts!(facts, message_id)
    self.facts = facts
    self.facts_message_id = message_id
    self.facts_at = Time.current
    apply_score
    save!
  end

  private

  def apply_score
    result = Sales::ScoreFormula.compute(facts: facts, risk: risk, previous_band: score_band_was)
    self.score = result[:score]
    self.score_band = result[:band]
    self.score_factors = result[:factors]
  end
end
