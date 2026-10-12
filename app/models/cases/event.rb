# Histórico do caso, só de acréscimo: o que mudou, quem mudou e quando. O
# `metadata` guarda os valores de antes e depois (`from`/`to`). `team_reply` é
# a resposta da equipe que a IA repassa ao cliente (metadata `mode`
# answer/ask e `relay` pending/sent/failed, pelo workflow "CortexGen Caso");
# `customer_replied` é o que o cliente respondeu a uma pergunta repassada.
class Cases::Event < ApplicationRecord
  self.table_name = 'cases_events'

  belongs_to :account
  belongs_to :case, class_name: 'Cases::Case', inverse_of: :events
  belongs_to :actor, class_name: 'User', optional: true

  enum :kind, { created: 0, status_changed: 1, assigned: 2, priority_changed: 3, due_changed: 4, field_changed: 5, note: 6,
                conversation_linked: 7, ai_note: 8, customer_notified: 9, type_changed: 10, team_reply: 11, customer_replied: 12 },
       validate: true
  enum :actor_kind, { user: 0, ai: 1, system: 2 }, prefix: :by, validate: true

  RELAY_MODES = %w[answer ask].freeze

  validates :body, presence: true, if: -> { note? || ai_note? || team_reply? || customer_replied? }

  scope :relay_pending, -> { team_reply.where("metadata->>'relay' = 'pending'") }
end
