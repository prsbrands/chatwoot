# Tarefas do funil: o que ficou combinado, com prazo e responsável, ligado a um
# negócio ou a um contato. Negócio aberto sem tarefa pendente é o "sem próximo
# passo" do Radar.
class CreateSalesTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_tasks do |t|
      t.references :account, null: false, index: false
      t.string :title, null: false
      t.text :notes
      t.datetime :due_at
      t.references :deal, index: true
      t.references :contact, index: true
      t.references :assignee, index: true
      t.bigint :created_by_id
      t.datetime :completed_at
      t.bigint :completed_by_id
      t.timestamps
    end
    # A lista padrão: pendentes da conta, por prazo.
    add_index :sales_tasks, [:account_id, :completed_at, :due_at]
  end
end
