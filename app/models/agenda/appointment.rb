# Compromisso com hora marcada, de um responsável (owner), ligado a um contato,
# negócio ou conversa, ou só da pessoa. Quando o responsável tem o Google
# conectado, o compromisso vai para a agenda dele (Agenda::GooglePushJob).
class Agenda::Appointment < ApplicationRecord
  self.table_name = 'agenda_appointments'

  belongs_to :account
  belongs_to :owner, class_name: 'User', optional: true
  belongs_to :contact, optional: true
  belongs_to :deal, class_name: 'Sales::Deal', optional: true
  belongs_to :conversation, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3, no_show: 4 }, validate: true

  validates :title, :starts_at, :ends_at, presence: true
  validate :ends_after_start

  before_validation { self.contact_id = deal.contact_id if deal }
  after_commit :push_to_google

  scope :between, ->(from, to) { where('starts_at < ? AND ends_at > ?', to, from) }

  # Id do evento no Google fixo por compromisso: criar de novo depois de uma
  # falha no meio do caminho não duplica (o Google responde 409 e vira update).
  # Base32hex: só 0-9 e a-v.
  def google_event_key
    "cgchat#{id}"
  end

  private

  def ends_after_start
    errors.add(:ends_at, :invalid) if starts_at && ends_at && ends_at <= starts_at
  end

  def push_to_google
    Agenda::GooglePushJob.perform_later(id, google_connection_id)
  end
end
