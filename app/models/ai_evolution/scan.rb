# Até onde a Evolução da IA já leu uma conversa: a próxima rodada só lê o que
# veio depois (o mesmo trecho nunca é pago duas vezes). `claimed_at` reserva a
# conversa para uma rodada; o LLM que falhou tenta de novo depois de 1 h.
class AiEvolution::Scan < ApplicationRecord
  self.table_name = 'ai_evolution_scans'

  belongs_to :account
  belongs_to :conversation
end
