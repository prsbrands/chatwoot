# O resumo do cliente que a IA mantém (um por contato, em todos os canais) e
# até onde ela já leu: `last_message_id` é o maior id de mensagem considerado.
class AiMemory::Summary < ApplicationRecord
  self.table_name = 'ai_memory_summaries'
  MAX_LENGTH = 1500

  belongs_to :account
  belongs_to :contact

  before_validation { self.account_id ||= contact&.account_id }
  before_save { self.body = body.to_s.strip.truncate(MAX_LENGTH) }
end
