# Automação por conta: o cliente aceita a cotização pelo link e a fatura nasce
# e vai sozinha pelos canais da cotização (Commerce::AutoInvoiceJob).
class AddAutoInvoiceToCommerceProfiles < ActiveRecord::Migration[7.1]
  def change
    add_column :commerce_profiles, :auto_invoice_on_accept, :boolean, null: false, default: false
  end
end
