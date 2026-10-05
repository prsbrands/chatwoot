# Comercial, fase 2: orçamentos e faturas. O documento guarda uma cópia dos
# dados da empresa e do cliente no momento em que foi gerado (editar a empresa
# depois não muda o que já foi enviado), as linhas com o imposto de cada uma, os
# pagamentos recebidos e, no ActiveStorage, todo PDF gerado (o arquivo).
class CreateCommerceDocuments < ActiveRecord::Migration[7.1]
  def change
    create_documents
    create_document_items
    create_document_payments
    add_column :commerce_profiles, :quote_prefix, :string, null: false, default: 'COT'
    add_column :commerce_profiles, :invoice_prefix, :string, null: false, default: 'FAT'
  end

  private

  def create_documents
    create_table :commerce_documents do |t|
      t.references :account, null: false, index: false
      t.integer :kind, null: false, default: 0
      t.string :number, null: false
      t.integer :year, null: false
      t.integer :sequence, null: false
      t.integer :status, null: false, default: 0
      t.string :language, null: false, default: 'es'
      t.string :currency, null: false, default: 'USD'
      t.integer :tax_mode, null: false, default: 0
      t.references :contact, index: true
      t.references :deal, index: true
      t.references :appointment, index: false
      t.references :conversation, index: false
      t.references :source_document, index: true
      t.date :issue_date, null: false
      t.date :due_date
      t.string :public_token, null: false
      t.bigint :created_by_id
      t.timestamps
    end
    add_document_contents
    add_index :commerce_documents, [:account_id, :kind, :year, :sequence], unique: true, name: 'index_commerce_documents_on_number'
    add_index :commerce_documents, [:account_id, :kind, :status]
    add_index :commerce_documents, :public_token, unique: true
  end

  # Cópias da empresa e do cliente, totais, textos e as datas de cada passo.
  def add_document_contents
    change_table :commerce_documents, bulk: true do |t|
      t.jsonb :customer, null: false, default: {}
      t.jsonb :company, null: false, default: {}
      t.decimal :subtotal, :discount_total, :tax_total, :total, :amount_paid, precision: 14, scale: 2, null: false, default: 0
      t.text :notes, :terms, :footer
      t.datetime :sent_at, :accepted_at, :declined_at, :paid_at, :voided_at
    end
  end

  def create_document_items
    create_table :commerce_document_items do |t|
      t.references :document, null: false, index: true
      t.references :item, index: false
      t.string :name, null: false
      t.text :description
      t.decimal :quantity, precision: 14, scale: 3, null: false, default: 1
      t.string :unit, null: false, default: 'unit'
      t.decimal :unit_price, precision: 14, scale: 2
      t.decimal :discount_percent, :tax_rate, precision: 5, scale: 2, null: false, default: 0
      t.decimal :line_subtotal, :line_discount, :line_tax, :line_total, precision: 14, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end

  def create_document_payments
    create_table :commerce_document_payments do |t|
      t.references :account, null: false, index: false
      t.references :document, null: false, index: true
      t.references :payment_method, index: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :paid_on, null: false
      t.string :note
      t.bigint :created_by_id
      t.timestamps
    end
  end
end
