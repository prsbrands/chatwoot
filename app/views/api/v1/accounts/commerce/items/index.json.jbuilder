json.payload @items do |item|
  json.partial! 'api/v1/models/commerce_item', formats: [:json], resource: item
end
