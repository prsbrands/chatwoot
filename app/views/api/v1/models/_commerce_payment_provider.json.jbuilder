json.call(resource, :id, :provider, :environment, :active, :credential_hint, :webhook_url)
json.currencies Commerce::PaymentProvider::CURRENCIES.fetch(resource.provider)
