# Comercial, fase 4b: a vitrine pública do catálogo (/c/:token), ligada pela
# empresa. O token aleatório é o endereço; desligar tira a página do ar.
class AddStorefrontToCommerceProfiles < ActiveRecord::Migration[7.1]
  def change
    change_table :commerce_profiles, bulk: true do |t|
      t.boolean :storefront_enabled, null: false, default: false
      t.string :storefront_token
    end
    add_index :commerce_profiles, :storefront_token, unique: true
  end
end
