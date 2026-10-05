# Arquivar é pedido pela pessoa (orçamento perdido, vencido...): o documento sai
# da lista principal e fica em Arquivados, de onde pode voltar.
class AddArchivedAtToCommerceDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :commerce_documents, :archived_at, :datetime
  end
end
