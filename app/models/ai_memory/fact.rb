# Um fato curto sobre o cliente ("tem 3 lojas em Colón", "prefere falar depois
# das 18 h"). A IA só mexe no que ela escreveu e ninguém fixou: fato manual ou
# fixado fica como a pessoa deixou.
class AiMemory::Fact < ApplicationRecord
  self.table_name = 'ai_memory_facts'
  MAX_LENGTH = 300

  belongs_to :account
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  enum :source, { ai: 0, manual: 1 }, validate: true

  validates :body, presence: true, length: { maximum: MAX_LENGTH }

  before_validation do
    self.account_id ||= contact&.account_id
    self.body = body.to_s.squish
  end

  scope :ordered, -> { order(pinned: :desc, created_at: :asc) }
  scope :editable_by_ai, -> { ai.where(pinned: false) }

  def locked?
    pinned? || manual?
  end

  def as_api_json
    slice(:id, :body, :source, :pinned, :created_at, :updated_at).merge(conversation_display_id: conversation&.display_id)
  end
end
