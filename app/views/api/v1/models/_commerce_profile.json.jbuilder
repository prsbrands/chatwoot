json.call(resource, :trade_name, :legal_name, :tax_id_label, :tax_id, :address, :phone, :whatsapp, :email, :website,
          :default_currency, :default_terms, :footer, :quote_prefix, :invoice_prefix, :receipt_prefix, :storefront_enabled, :storefront_url)
json.logo_url resource.logo.attached? ? url_for(resource.logo) : nil
