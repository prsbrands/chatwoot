# Evolução da IA (flag `ai_evolution`): o que a IA aprende com a equipe. Uma
# rodada por dia lê as conversas com sinal (passagem com resposta da equipe,
# resposta retida pelo Jev, caso aberto pela IA) e propõe mudanças na base e
# no prompt da persona, que a equipe aplica ou recusa. Desenho em
# docs/cortexgen/evolucao.md.
class CreateAiEvolution < ActiveRecord::Migration[7.1]
  def change
    create_scans
    create_suggestions
  end

  private

  def create_scans
    create_table :ai_evolution_scans do |t|
      t.references :account, null: false, index: false
      t.references :conversation, null: false, index: { unique: true }
      # Maior id de mensagem já lido: a próxima rodada só lê o que veio depois.
      t.bigint :last_message_id, null: false, default: 0
      # Reservada para uma rodada; LLM que falhou volta depois de 1 h.
      t.datetime :claimed_at
      t.datetime :scanned_at
      t.timestamps
    end
    add_index :ai_evolution_scans, [:account_id, :scanned_at]
  end

  def create_suggestions
    create_table :ai_evolution_suggestions do |t|
      t.references :account, null: false, index: false
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.string :persona_id, null: false
      t.string :persona_name
      t.string :title, null: false
      t.text :content, null: false
      target_columns(t)
      t.text :rationale
      t.jsonb :evidence, null: false, default: []
      t.integer :evidence_count, null: false, default: 0
      t.boolean :edited, null: false, default: false
      decision_columns(t)
      t.timestamps
    end
    add_index :ai_evolution_suggestions, [:account_id, :status, :evidence_count], name: 'index_ai_evolution_suggestions_on_queue'
  end

  # Onde a proposta mexe: o documento da base (e o trecho que a correção
  # troca) ou o prompt da persona; `applied_change` guarda o antes e o depois
  # para desfazer.
  def target_columns(table)
    table.string :target_doc_id
    table.string :target_doc_title
    table.text :replace_text
    table.jsonb :applied_change
  end

  def decision_columns(table)
    table.datetime :applied_at
    table.references :applied_by, index: false
    table.datetime :rejected_at
    table.references :rejected_by, index: false
    table.text :reject_reason
  end
end
