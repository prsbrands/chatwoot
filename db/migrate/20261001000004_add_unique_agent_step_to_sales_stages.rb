# O passo do agente e unico por funil (Sales::Stage valida). Sem o indice, dois
# saves simultaneos passavam pela validacao e o Jev ficaria com duas etapas
# para o mesmo passo.
class AddUniqueAgentStepToSalesStages < ActiveRecord::Migration[7.1]
  def change
    add_index :sales_stages, [:pipeline_id, :agent_step], unique: true, where: 'agent_step IS NOT NULL',
                                                          name: 'index_sales_stages_unique_agent_step'
  end
end
