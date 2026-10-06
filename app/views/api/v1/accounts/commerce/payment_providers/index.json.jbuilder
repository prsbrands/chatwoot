json.payload @providers do |provider|
  json.partial! 'api/v1/models/commerce_payment_provider', formats: [:json], resource: provider
end
