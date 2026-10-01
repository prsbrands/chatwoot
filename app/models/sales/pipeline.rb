# Funil de vendas da conta (bloco 3a). Toda conta com a flag `sales_pipeline`
# ganha um funil padrao na primeira vez que alguem precisa dele, com as etapas
# no idioma da conta e o passo do agente (agent_step) ja preenchido: no
# DeskComm, 308 de 312 etapas nasceram sem esse passo e a IA nunca movia nada.
class Sales::Pipeline < ApplicationRecord
  self.table_name = 'sales_pipelines'

  DEFAULT_STAGES = {
    'pt' => ['Novo contato', 'Já respondi', 'Entendendo a necessidade', 'Proposta enviada', 'Negociando', 'Fechou', 'Não fechou'],
    'es' => ['Nuevo contacto', 'Ya respondí', 'Entendiendo la necesidad', 'Propuesta enviada', 'Negociando', 'Cerró', 'No cerró'],
    'en' => ['New lead', 'Contacted', 'Qualifying', 'Proposal sent', 'Negotiating', 'Won', 'Lost']
  }.freeze
  DEFAULT_NAMES = { 'pt' => 'Vendas', 'es' => 'Ventas', 'en' => 'Sales' }.freeze
  AGENT_STEPS = %w[new contacted qualifying qualified negotiating].freeze

  belongs_to :account
  # Negocios antes das etapas: a etapa recusa ser apagada com negocio dentro.
  has_many :deals, class_name: 'Sales::Deal', dependent: :destroy, inverse_of: :pipeline
  has_many :stages, -> { order(:position) }, class_name: 'Sales::Stage', dependent: :destroy, inverse_of: :pipeline

  validates :name, presence: true

  # O padrao nasce sob lock da conta: duas mensagens ao mesmo tempo nao criam
  # dois funis.
  def self.default_for(account)
    account.with_lock do
      account.sales_pipelines.find_by(is_default: true) || create_default!(account)
    end
  end

  def self.create_default!(account)
    language = account.locale.to_s.split('_').first
    language = 'en' unless DEFAULT_STAGES.key?(language)
    pipeline = account.sales_pipelines.create!(name: DEFAULT_NAMES[language], is_default: true)
    DEFAULT_STAGES[language].each_with_index do |name, index|
      kind = { 5 => :won, 6 => :lost }.fetch(index, :open)
      pipeline.stages.create!(account: account, name: name, position: index, kind: kind, agent_step: AGENT_STEPS[index])
    end
    pipeline
  end

  # Moeda dos negocios novos: a conta em portugues vende em real.
  def self.currency_for(account)
    account.locale.to_s.start_with?('pt') ? 'BRL' : 'USD'
  end

  def first_open_stage
    stages.find_by(kind: :open)
  end
end
