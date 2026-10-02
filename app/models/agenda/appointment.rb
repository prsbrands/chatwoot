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
  belongs_to :event_type, class_name: 'Agenda::EventType', optional: true

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3, no_show: 4 }, validate: true

  validates :title, :starts_at, :ends_at, presence: true
  validate :ends_after_start

  before_validation { self.contact_id = deal.contact_id if deal }
  after_create :advance_deal
  after_commit :push_to_google
  after_update_commit :message_no_show, if: -> { saved_change_to_status? && no_show? }

  scope :between, ->(from, to) { where('starts_at < ? AND ends_at > ?', to, from) }

  # Id do evento no Google fixo por compromisso: criar de novo depois de uma
  # falha no meio do caminho não duplica (o Google responde 409 e vira update).
  # Base32hex: só 0-9 e a-v.
  def google_event_key
    "cgchat#{id}"
  end

  # Compromissos que já acabaram sem desfecho (nem realizado, nem não
  # compareceu, nem cancelado): o Radar cobra a presença.
  scope :awaiting_outcome, -> { where(status: %i[pending confirmed]).where(ends_at: 30.days.ago..Time.current) }

  private

  # Só para a frente e no mesmo funil: marcar não desfaz o que o negócio já
  # andou. Quem moveu fica no histórico (a pessoa, ou a IA quando foi ela).
  def advance_deal
    stage = event_type&.booked_stage
    return unless stage && deal&.open? && ahead_in_same_pipeline?(stage)

    deal.move_to!(stage, actor: created_by || 'ai', reason: I18n.t('agenda.deal_moved', type: event_type.name))
  end

  def ahead_in_same_pipeline?(stage)
    stage.pipeline_id == deal.pipeline_id && stage.position > deal.stage.position
  end

  # A IA (ou a equipe, se a resposta vier para ela) retoma pela conversa: o
  # cliente responde e a atividade de agendamento do Jev oferece outro horário.
  def message_no_show
    return if event_type&.no_show_message.blank?

    ::Agenda::CustomerMessage.new(self, event_type.no_show_message).deliver
  end

  def ends_after_start
    errors.add(:ends_at, :invalid) if starts_at && ends_at && ends_at <= starts_at
  end

  def push_to_google
    Agenda::GooglePushJob.perform_later(id, google_connection_id)
  end
end
