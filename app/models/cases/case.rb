# O caso: o que o cliente pediu e não se resolve na hora. Número CAS-2026-0001
# por conta e por ano (prefixo em `account.cases_prefix`). O prazo nasce do tipo
# e pausa enquanto o caso espera o cliente (`paused_at`). Quem muda a situação,
# o responsável e os campos é o Cases::CaseFlow, que grava o histórico.
class Cases::Case < ApplicationRecord
  self.table_name = 'cases_cases'

  DEFAULT_PREFIX = 'CAS'.freeze
  ACTIVE = %w[open in_progress waiting_customer].freeze
  # Formato de cada tipo de campo próprio (Cases::Type::FIELD_TYPES).
  FIELD_CHECKS = {
    'text' => ->(value, _field) { value.is_a?(String) && value.size <= 2000 },
    'number' => ->(value, _field) { value.is_a?(Numeric) },
    'date' => ->(value, _field) { value.is_a?(String) && Date.iso8601(value).present? },
    'select' => ->(value, field) { field['options'].include?(value) },
    'boolean' => ->(value, _field) { [true, false].include?(value) }
  }.freeze

  belongs_to :account
  belongs_to :type, class_name: 'Cases::Type', inverse_of: :cases
  belongs_to :contact
  belongs_to :deal, class_name: 'Sales::Deal', optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :team, optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :case_conversations, class_name: 'Cases::CaseConversation', dependent: :delete_all, inverse_of: :case
  has_many :conversations, through: :case_conversations
  has_many :events, -> { order(:created_at, :id) }, class_name: 'Cases::Event', dependent: :delete_all, inverse_of: :case

  enum :status, { open: 0, in_progress: 1, waiting_customer: 2, resolved: 3, canceled: 4 }, validate: true
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }, validate: true
  enum :source, { manual: 0, conversation: 1, ai: 2 }, prefix: true, validate: true
  enum :outcome, { solved: 0, not_applicable: 1, duplicate: 2, no_response: 3 }, validate: { allow_nil: true }

  validates :title, presence: true
  validate :field_values_fit_type

  before_validation :assign_number, on: :create
  before_validation :assign_due_at, on: :create

  scope :active, -> { where(status: ACTIVE) }
  scope :overdue, -> { active.where(paused_at: nil).where(due_at: ...Time.current) }

  def active?
    ACTIVE.include?(status)
  end

  def overdue?
    active? && paused_at.nil? && due_at&.past?
  end

  # A conversa por onde o cliente fala com o caso: a de origem ou, sem ela, a
  # ligada mais recente.
  def main_conversation
    conversations.reorder('cases_conversations.origin DESC, cases_conversations.created_at DESC').first
  end

  # Idioma das mensagens ao cliente: o que a IA viu ao abrir o caso, o da
  # conversa ou o da conta.
  def customer_language
    language = events.created.first&.metadata&.dig('language') || main_conversation&.language || account.locale
    Cases::CustomerLabels.normalize(language)
  end

  # A equipe perguntou algo ao cliente pela IA e ele ainda não respondeu.
  def awaiting_customer_info?
    return false unless waiting_customer?

    ask = events.team_reply.where("metadata->>'mode' = 'ask' AND metadata->>'relay' = 'sent'").last
    ask.present? && !events.customer_replied.exists?(['id > ?', ask.id])
  end

  # Campos obrigatórios do tipo sem valor: exigidos só ao resolver.
  def missing_required_fields
    type.fields.select { |field| field['required'] && field_values[field['key']].blank? && field_values[field['key']] != false }
  end

  private

  def assign_number
    return if number.present?

    self.year = Time.current.year
    self.sequence = account.cases.where(year: year).maximum(:sequence).to_i + 1
    self.number = "#{account.cases_prefix.presence || DEFAULT_PREFIX}-#{year}-#{sequence.to_s.rjust(4, '0')}"
  end

  def assign_due_at
    self.due_at ||= type.sla_hours.hours.from_now if type&.sla_hours
  end

  # Só os campos que o tipo tem, cada um no seu formato. Campo apagado do tipo
  # que ficou no caso é histórico: segue gravado e não se valida.
  def field_values_fit_type
    return errors.add(:field_values, :invalid) unless field_values.is_a?(Hash)
    return unless type && will_save_change_to_field_values?

    changed = field_values.reject { |key, value| field_values_was.to_h[key] == value }
    errors.add(:field_values, :invalid) unless changed.all? { |key, value| valid_field_value?(type.field(key), value) }
  end

  def valid_field_value?(field, value)
    return false unless field

    value.nil? || value == '' || FIELD_CHECKS.fetch(field['type']).call(value, field)
  rescue Date::Error
    false
  end
end
