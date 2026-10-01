# Bloco 3b: a etapa que o Jev sugere (confianca entre 0,5 e 0,8, ou "fechou")
# fica no negocio ate alguem aceitar, descartar ou mover o negocio.
class AddSuggestionToSalesDeals < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_deals, :suggested_stage_id, :bigint
    add_column :sales_deals, :suggested_confidence, :float
    add_column :sales_deals, :suggested_at, :datetime
  end
end
