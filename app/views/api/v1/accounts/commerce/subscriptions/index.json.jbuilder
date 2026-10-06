json.payload @subscriptions do |subscription|
  json.partial! 'api/v1/models/commerce_subscription', formats: [:json], resource: subscription
end
