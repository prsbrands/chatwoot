# Comercial: catálogo, dados da empresa, formas de pagamento, orçamentos,
# faturas, cobrança online e assinaturas. Flag `commerce` por conta.
module Commerce
  CURRENCIES = %w[USD BRL EUR].freeze

  # O cliente como sai num documento ou assinatura: nome, e-mail e telefone do
  # contato, com os dados fiscais lembrados do último documento (billing_*).
  def self.customer_of(contact)
    billing = (contact.additional_attributes || {}).slice('billing_tax_id_label', 'billing_tax_id', 'billing_address')
                                                   .transform_keys { |key| key.delete_prefix('billing_') }
    { 'name' => contact.name, 'email' => contact.email, 'phone' => contact.phone_number }.merge(billing).compact_blank
  end

  def self.table_name_prefix
    'commerce_'
  end
end
