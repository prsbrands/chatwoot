# Tipo de caso da conta: nome, prazo, prioridade e responsável padrão, os
# campos próprios do negócio e o que a IA faz com ele. A conta sem tipos ganha
# um modelo neutro no idioma dela na primeira leitura; o admin edita.
class Cases::Type < ApplicationRecord
  self.table_name = 'cases_types'

  FIELD_TYPES = %w[text number date select boolean].freeze
  FIELD_KEY = /\A[a-z][a-z0-9_]{0,39}\z/.freeze
  # [nome, prazo em horas, prioridade] no idioma da conta.
  TEMPLATE = {
    'pt' => [['Dúvida', 24, :normal], ['Problema', 8, :high], ['Solicitação', 48, :normal], ['Reclamação', 4, :high], ['Financeiro', 24, :normal]],
    'es' => [['Duda', 24, :normal], ['Problema', 8, :high], ['Solicitud', 48, :normal], ['Reclamo', 4, :high], ['Financiero', 24, :normal]],
    'en' => [['Question', 24, :normal], ['Problem', 8, :high], ['Request', 48, :normal], ['Complaint', 4, :high], ['Billing', 24, :normal]]
  }.freeze
  TEMPLATE_COLORS = %w[#3B82F6 #EF4444 #10B981 #F59E0B #8B5CF6].freeze

  belongs_to :account
  belongs_to :default_assignee, class_name: 'User', optional: true
  belongs_to :default_team, class_name: 'Team', optional: true
  has_many :cases, class_name: 'Cases::Case', dependent: :restrict_with_error, inverse_of: :type

  enum :default_priority, { low: 0, normal: 1, high: 2, urgent: 3 }, prefix: true, validate: true
  # off: a IA não abre; continue: abre e segue atendendo; handoff: abre e passa a conversa.
  enum :ai_mode, { off: 0, continue: 1, handoff: 2 }, prefix: :ai, validate: true

  validates :name, presence: true
  validates :sla_hours, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :fields_are_valid

  scope :ordered, -> { order(:position, :id) }

  def self.for(account)
    account.with_lock { account.cases_types.exists? || create_template!(account) }
    account.cases_types.ordered
  end

  def self.create_template!(account)
    language = account.locale.to_s.split('_').first
    TEMPLATE.fetch(language, TEMPLATE['en']).each_with_index do |(name, hours, priority), index|
      account.cases_types.create!(name: name, sla_hours: hours, default_priority: priority, position: index, color: TEMPLATE_COLORS[index])
    end
  end

  def field(key)
    fields.find { |field| field['key'] == key }
  end

  private

  def fields_are_valid
    return errors.add(:fields, :invalid) unless fields.is_a?(Array) && fields.all? { |field| field.is_a?(Hash) && valid_field?(field) }

    errors.add(:fields, :taken) if fields.pluck('key').uniq.size != fields.size
  end

  def valid_field?(field)
    field['key'].to_s.match?(FIELD_KEY) && field['label'].present? && FIELD_TYPES.include?(field['type']) &&
      (field['type'] != 'select' || valid_options?(field['options']))
  end

  def valid_options?(options)
    options.is_a?(Array) && options.any? && options.all?(String)
  end
end
