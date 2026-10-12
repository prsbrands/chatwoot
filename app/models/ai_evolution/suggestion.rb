# Uma proposta da Evolução da IA para a base de conhecimento ou para o prompt
# de uma persona (as duas ficam no Supabase do botlayer; aqui só o id e o
# nome). A evidência são as conversas que ensinaram a mesma coisa: a frase do
# cliente e o que a equipe respondeu. Quem aplica e desfaz é o
# AiEvolution::Applier.
class AiEvolution::Suggestion < ApplicationRecord
  self.table_name = 'ai_evolution_suggestions'

  MAX_EVIDENCE = 10
  TITLE_LENGTH = 120
  CONTENT_LENGTH = 2000

  belongs_to :account
  belongs_to :applied_by, class_name: 'User', optional: true
  belongs_to :rejected_by, class_name: 'User', optional: true

  # knowledge_add: seção nova na base; knowledge_update: troca `replace_text`
  # num documento; prompt_rule: regra no fim do prompt da persona.
  enum :kind, { knowledge_add: 0, knowledge_update: 1, prompt_rule: 2 }, validate: true
  enum :status, { pending: 0, applied: 1, rejected: 2 }, validate: true

  validates :persona_id, :title, :content, presence: true
  validates :title, length: { maximum: TITLE_LENGTH }
  validates :content, length: { maximum: CONTENT_LENGTH }
  validates :target_doc_id, :replace_text, presence: true, if: :knowledge_update?

  scope :queue, -> { order(evidence_count: :desc, created_at: :asc) }

  # Mais uma conversa que ensina a mesma coisa; guarda as mais recentes.
  def add_evidence!(item)
    list = (evidence + [item]).last(MAX_EVIDENCE)
    update!(evidence: list, evidence_count: evidence_count + 1)
  end
end
