# Casos (flag `cases`): o que o cliente pediu e não se resolve na hora, com
# tipo, dono, prazo e desfecho. Os tipos são da conta (nascem de um modelo
# neutro no idioma dela) e trazem os campos próprios de cada negócio. Desenho
# em docs/cortexgen/casos.md.
class CreateCases < ActiveRecord::Migration[7.1]
  def change
    create_types
    create_cases
    create_case_conversations
    create_events
  end

  private

  def create_types
    create_table :cases_types do |t|
      t.references :account, null: false, index: false
      t.string :name, null: false
      t.string :color, null: false, default: '#6B7280'
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      # Prazo em horas corridas a partir da abertura; nulo = sem prazo.
      t.integer :sla_hours
      t.integer :default_priority, null: false, default: 1
      t.references :default_assignee, index: false
      t.references :default_team, index: false
      # [{ key, label, type, options, required }]
      t.jsonb :fields, null: false, default: []
      t.integer :ai_mode, null: false, default: 0
      t.text :ai_instructions
      t.boolean :notify_customer, null: false, default: false
      t.timestamps
    end
    add_index :cases_types, [:account_id, :position]
  end

  def create_cases
    create_table :cases_cases do |t|
      t.references :account, null: false, index: false
      t.references :type, null: false, index: true
      number_columns(t)
      t.string :title, null: false
      t.text :description
      work_columns(t)
      t.references :contact, null: false, index: true
      t.references :deal, index: true
      t.integer :source, null: false, default: 0
      t.jsonb :field_values, null: false, default: {}
      outcome_columns(t)
      t.references :created_by, index: false
      t.timestamps
    end
    add_index :cases_cases, [:account_id, :year, :sequence], unique: true, name: 'index_cases_cases_on_number'
    add_index :cases_cases, [:account_id, :status, :due_at]
  end

  def work_columns(table)
    table.integer :status, null: false, default: 0
    table.integer :priority, null: false, default: 1
    table.references :assignee, index: true
    table.references :team, index: false
    table.datetime :due_at
    # Desde quando espera o cliente: o prazo anda esse tempo ao voltar.
    table.datetime :paused_at
  end

  def number_columns(table)
    table.string :number, null: false
    table.integer :year, null: false
    table.integer :sequence, null: false
  end

  def outcome_columns(table)
    table.integer :outcome
    table.text :resolution
    table.datetime :resolved_at
    table.references :resolved_by, index: false
    table.datetime :canceled_at
  end

  def create_case_conversations
    create_table :cases_conversations do |t|
      t.references :account, null: false, index: false
      t.references :case, null: false, index: false
      t.references :conversation, null: false, index: true
      # A conversa de onde o caso nasceu.
      t.boolean :origin, null: false, default: false
      t.timestamps
    end
    add_index :cases_conversations, [:case_id, :conversation_id], unique: true
  end

  def create_events
    create_table :cases_events do |t|
      t.references :account, null: false, index: false
      t.references :case, null: false, index: false
      t.integer :kind, null: false
      t.integer :actor_kind, null: false, default: 0
      t.references :actor, index: false
      t.text :body
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :cases_events, [:case_id, :created_at]
  end
end
