# Comercial, fase 3d: assinaturas mensais e anuais. O plano é um item do
# catálogo com billing_interval; a assinatura guarda a cópia do plano (nome,
# preço, moeda, ciclo) e do cliente, porque o catálogo pode mudar depois. Cada
# ciclo cobrado vira uma fatura (subscription_id, período) paga por um checkout
# com o id da cobrança do provedor, e o recibo sai como no pagamento avulso.
class CreateCommerceSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :commerce_items, :billing_interval, :integer, null: false, default: 0
    change_table :commerce_documents, bulk: true do |t|
      t.bigint :subscription_id
      t.date :period_start
      t.date :period_end
    end
    add_index :commerce_documents, :subscription_id
    create_subscriptions
    add_index :commerce_subscriptions, [:account_id, :status]
    add_index :commerce_subscriptions, :public_token, unique: true
    add_index :commerce_subscriptions, [:provider_id, :external_id], unique: true
  end

  private

  def create_subscriptions
    create_table :commerce_subscriptions do |t|
      t.references :account, null: false, index: false
      t.references :contact, index: true
      t.bigint :deal_id, :conversation_id, :item_id, :provider_id, :payment_method_id, :created_by_id
      t.string :name, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 1
      t.decimal :unit_price, precision: 14, scale: 2, null: false
      t.string :currency, null: false
      t.integer :interval, null: false
      t.integer :status, null: false, default: 0
      t.string :language, null: false, default: 'es'
      t.jsonb :customer, null: false, default: {}
      t.string :public_token, null: false
      t.string :external_id
      t.datetime :current_period_start, :current_period_end, :canceled_at, :sent_at
      t.boolean :cancel_at_period_end, null: false, default: false
      t.timestamps
    end
  end
end
