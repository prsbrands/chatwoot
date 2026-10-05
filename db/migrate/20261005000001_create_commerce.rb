# Comercial, fase 1: o catálogo (produtos e serviços, com preço opcional — o
# que é orçado ou feito sob medida fica sem preço), os dados da empresa que vão
# nos orçamentos e faturas, e as formas de pagamento que a conta aceita. As
# imagens dos itens e o logo da empresa ficam no ActiveStorage.
class CreateCommerce < ActiveRecord::Migration[7.1]
  def change
    create_categories
    create_items
    create_profiles
    create_payment_methods
  end

  private

  def create_categories
    create_table :commerce_categories do |t|
      t.references :account, null: false, index: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :commerce_categories, [:account_id, :position]
  end

  def create_items
    create_table :commerce_items do |t|
      t.references :account, null: false, index: false
      t.references :category, index: true
      t.integer :kind, null: false, default: 0
      t.string :name, null: false
      t.text :description
      t.string :sku
      t.decimal :price, precision: 14, scale: 2
      t.string :currency, null: false, default: 'USD'
      t.string :unit, null: false, default: 'unit'
      t.boolean :available, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :commerce_items, [:account_id, :kind, :name]
  end

  def create_profiles
    create_table :commerce_profiles do |t|
      t.references :account, null: false, index: { unique: true }
      %i[trade_name legal_name tax_id_label tax_id phone whatsapp email website].each { |column| t.string column }
      t.text :address
      t.string :default_currency, null: false, default: 'USD'
      t.text :default_terms
      t.text :footer
      t.timestamps
    end
  end

  def create_payment_methods
    create_table :commerce_payment_methods do |t|
      t.references :account, null: false, index: false
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.text :instructions
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :commerce_payment_methods, [:account_id, :position]
  end
end
