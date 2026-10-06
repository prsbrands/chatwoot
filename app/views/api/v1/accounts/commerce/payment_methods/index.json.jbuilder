json.payload @payment_methods do |method|
  json.call(method, :id, :name, :kind, :instructions, :active, :position, :provider_id)
  json.charges_subscriptions Commerce::Subscription::PROVIDERS.include?(method.provider&.provider)
end
