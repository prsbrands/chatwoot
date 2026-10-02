# Tarefa do funil: o que ficou combinado, com prazo e responsável. Ligada a um
# negócio (e então ao contato dele) ou só a um contato. Concluir guarda quem e
# quando; reabrir limpa os dois.
class Sales::Task < ApplicationRecord
  self.table_name = 'sales_tasks'

  belongs_to :account
  belongs_to :deal, class_name: 'Sales::Deal', optional: true
  belongs_to :contact, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :completed_by, class_name: 'User', optional: true

  validates :title, presence: true

  before_validation { self.contact_id = deal.contact_id if deal }

  scope :pending, -> { where(completed_at: nil) }
  scope :done, -> { where.not(completed_at: nil) }

  def done?
    completed_at.present?
  end

  def complete!(user)
    update!(completed_at: Time.current, completed_by: user)
  end

  def reopen!
    update!(completed_at: nil, completed_by: nil)
  end
end
