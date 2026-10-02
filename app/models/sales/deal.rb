# Negocio no funil. O status (open/won/lost) e sempre o da etapa: so `move_to!`
# troca de etapa, e cada troca grava quem moveu e por que (Sales::DealTransition).
class Sales::Deal < ApplicationRecord
  self.table_name = 'sales_deals'

  belongs_to :account
  belongs_to :pipeline, class_name: 'Sales::Pipeline'
  belongs_to :stage, class_name: 'Sales::Stage'
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :suggested_stage, class_name: 'Sales::Stage', optional: true
  has_one :insight, class_name: 'Sales::DealInsight', dependent: :delete, inverse_of: :deal
  has_many :tasks, class_name: 'Sales::Task', dependent: :delete_all, inverse_of: :deal
  has_many :appointments, class_name: 'Agenda::Appointment', dependent: :nullify, inverse_of: :deal
  has_many :transitions, -> { order(created_at: :desc) },
           class_name: 'Sales::DealTransition', dependent: :delete_all, inverse_of: :deal

  enum :status, { open: 0, won: 1, lost: 2 }

  validates :title, presence: true
  validates :value_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :lost_reason, presence: true, if: :lost?
  validate :stage_in_pipeline

  before_validation :sync_status_with_stage, if: :stage_id_changed?
  after_create_commit { record_transition(nil, actor_type: 'system', reason: nil) }

  # Abre o negocio do contato no funil padrao se ele nao tem um aberto. O lock
  # na linha do contato e o que impede tres mensagens seguidas de virarem tres
  # negocios (medido no DeskComm sem ele).
  def self.open_for_contact!(contact, conversation:)
    contact.with_lock do
      contact.account.sales_deals.open.find_by(contact: contact) || begin
        pipeline = Sales::Pipeline.default_for(contact.account)
        contact.account.sales_deals.create!(
          pipeline: pipeline, stage: pipeline.first_open_stage, contact: contact, conversation: conversation,
          currency: Sales::Pipeline.currency_for(contact.account),
          title: contact.name.presence || contact.phone_number.presence || "##{contact.id}"
        )
      end
    end
  end

  # Etapa de outro funil leva o negocio junto para esse funil.
  def move_to!(new_stage, actor:, reason: nil, lost_reason: nil)
    return self if new_stage.id == stage_id

    from_stage_id = stage_id
    transaction do
      # Qualquer movimento invalida a sugestao do Jev.
      update!(pipeline_id: new_stage.pipeline_id, stage: new_stage, lost_reason: new_stage.lost? ? lost_reason : nil,
              suggested_stage_id: nil, suggested_confidence: nil, suggested_at: nil)
      # O motivo da perda fica no historico: reabrir limpa o do negocio.
      record_transition(from_stage_id, actor_type: actor.is_a?(User) ? 'user' : actor.to_s, actor_id: actor.try(:id),
                                       reason: reason.presence || (new_stage.lost? ? lost_reason : nil))
    end
    self
  end

  def suggest!(stage, confidence)
    update!(suggested_stage: stage, suggested_confidence: confidence, suggested_at: Time.current)
  end

  def dismiss_suggestion!
    update!(suggested_stage_id: nil, suggested_confidence: nil, suggested_at: nil)
  end

  # O humano vence: depois de uma pessoa mexer no negocio, a IA so sugere.
  def recently_moved_by_human?(within)
    transitions.where(actor_type: 'user').exists?(['created_at > ?', within.ago])
  end

  private

  def sync_status_with_stage
    return if stage.blank?

    self.status = stage.kind
    self.stage_changed_at = Time.current
    self.closed_at = stage.open? ? nil : Time.current
  end

  def stage_in_pipeline
    errors.add(:stage, :invalid) if stage.present? && stage.pipeline_id != pipeline_id
  end

  def record_transition(from_stage_id, actor_type:, actor_id: nil, reason: nil)
    transitions.create!(account_id: account_id, from_stage_id: from_stage_id, to_stage_id: stage_id,
                        actor_type: actor_type, actor_id: actor_id, reason: reason)
  end
end
