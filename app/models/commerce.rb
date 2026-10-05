# Comercial: catálogo, dados da empresa, formas de pagamento e, nas próximas
# fases, orçamentos, faturas e cobrança online. Flag `commerce` por conta.
module Commerce
  CURRENCIES = %w[USD BRL EUR].freeze

  def self.table_name_prefix
    'commerce_'
  end
end
