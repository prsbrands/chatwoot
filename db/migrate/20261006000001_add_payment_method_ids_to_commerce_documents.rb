# Cada orçamento e fatura escolhe as formas de pagamento que mostra ao cliente
# (página, PDF, e-mail e botões "Pagar"). Até aqui saíam todas as ativas da
# conta: os documentos existentes ficam com elas, para não mudar o que já foi
# enviado.
class AddPaymentMethodIdsToCommerceDocuments < ActiveRecord::Migration[7.1]
  def up
    add_column :commerce_documents, :payment_method_ids, :bigint, array: true, null: false, default: []
    execute <<~SQL.squish
      UPDATE commerce_documents d
      SET payment_method_ids = COALESCE((SELECT array_agg(m.id ORDER BY m.position, m.id) FROM commerce_payment_methods m
                                         WHERE m.account_id = d.account_id AND m.active), '{}')
      WHERE d.kind IN (0, 1)
    SQL
  end

  def down
    remove_column :commerce_documents, :payment_method_ids
  end
end
