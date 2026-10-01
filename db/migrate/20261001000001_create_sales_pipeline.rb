# Funil de vendas do CortexGen Chat (bloco 3a). Prefixo `sales_` para nao
# colidir com um funil que o upstream venha a ter. Sem foreign key no banco
# (CLAUDE.md): as associacoes e o `dependent` dos models cuidam da exclusao.
class CreateSalesPipeline < ActiveRecord::Migration[7.1]
  def change
    create_pipelines
    create_stages
    create_deals
    create_transitions
  end

  private

  def create_pipelines
    create_table :sales_pipelines do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false
      t.boolean :is_default, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :sales_pipelines, :account_id, unique: true, where: 'is_default', name: 'index_sales_pipelines_one_default'
  end

  def create_stages
    create_table :sales_stages do |t|
      t.references :account, null: false, index: true
      t.references :pipeline, null: false, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      # open | won | lost: o status do negocio vem da etapa em que ele esta.
      t.integer :kind, null: false, default: 0
      # Nulo = 24 h. E a janela "fria" do radar de risco (bloco 3c).
      t.integer :expected_duration_hours
      t.boolean :requires_human, null: false, default: false
      # new | contacted | qualifying | qualified | negotiating: o passo que o
      # Jev reconhece (bloco 3b). Etapa sem passo a IA nao alcanca.
      t.string :agent_step
      t.timestamps
    end
    add_index :sales_stages, :pipeline_id, unique: true, where: 'kind = 1', name: 'index_sales_stages_one_won'
    add_index :sales_stages, :pipeline_id, unique: true, where: 'kind = 2', name: 'index_sales_stages_one_lost'
  end

  def create_deals
    create_table :sales_deals do |t|
      t.references :account, null: false, index: true
      t.references :pipeline, null: false, index: true
      t.references :stage, null: false, index: true
      t.references :contact, null: false, index: true
      t.references :conversation, index: true
      t.references :assignee, index: true
      t.string :title, null: false
      t.bigint :value_cents
      t.string :currency, null: false, default: 'USD'
      t.integer :status, null: false, default: 0
      t.string :lost_reason
      t.datetime :stage_changed_at, null: false
      t.datetime :closed_at
      t.timestamps
    end
    add_index :sales_deals, [:account_id, :contact_id, :status]
  end

  def create_transitions
    create_table :sales_deal_transitions do |t|
      t.references :account, null: false, index: true
      t.references :deal, null: false, index: true
      t.bigint :from_stage_id
      t.bigint :to_stage_id, null: false
      # user | ai | system
      t.string :actor_type, null: false
      t.bigint :actor_id
      t.text :reason
      t.datetime :created_at, null: false
    end
  end
end
