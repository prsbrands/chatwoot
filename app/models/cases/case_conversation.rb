# Conversa ligada ao caso; `origin` marca a conversa onde ele nasceu.
class Cases::CaseConversation < ApplicationRecord
  self.table_name = 'cases_conversations'

  belongs_to :account
  belongs_to :case, class_name: 'Cases::Case', inverse_of: :case_conversations
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :case_id }
end
