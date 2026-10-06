# Comercial, fase 3a: cobrança online e recibos. Cada conta conecta seus
# provedores (credenciais cifradas pela Active Record Encryption); a forma de
# pagamento aponta para um deles. Cada clique em "Pagar" é uma tentativa
# (checkout); o pagamento só nasce quando o provedor confirma, e o checkout_id
# único impede que o mesmo aviso pague duas vezes. O recibo é um documento.
class CreateCommerceCheckouts < ActiveRecord::Migration[7.1]
  def change
    create_providers
    create_checkouts
    add_column :commerce_payment_methods, :provider_id, :bigint
    change_table :commerce_document_payments, bulk: true do |t|
      t.bigint :checkout_id
      t.bigint :receipt_id
    end
    add_index :commerce_document_payments, :checkout_id, unique: true
    change_table :commerce_documents, bulk: true do |t|
      t.jsonb :details, null: false, default: {}
      t.string :delivered_email
    end
    add_column :commerce_profiles, :receipt_prefix, :string, null: false, default: 'REC'
  end

  private

  def create_providers
    create_table :commerce_payment_providers do |t|
      t.references :account, null: false, index: false
      t.integer :provider, null: false
      t.integer :environment, null: false, default: 0
      t.text :credentials
      t.text :webhook_secret
      t.string :webhook_token, null: false
      t.string :webhook_endpoint_id
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :commerce_payment_providers, [:account_id, :provider], unique: true
    add_index :commerce_payment_providers, :webhook_token, unique: true
  end

  def create_checkouts
    create_table :commerce_checkouts do |t|
      t.references :account, null: false, index: false
      t.references :document, null: false, index: true
      t.references :provider, null: false, index: false
      t.references :payment_method, index: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :currency, null: false
      t.integer :status, null: false, default: 0
      t.string :external_id
      t.text :checkout_url
      t.jsonb :payload, null: false, default: {}
      t.datetime :paid_at
      t.timestamps
    end
    add_index :commerce_checkouts, [:provider_id, :external_id], unique: true
    add_index :commerce_checkouts, [:status, :created_at]
  end
end
