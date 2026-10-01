json.payload @deals do |deal|
  json.partial! 'api/v1/models/sales_deal', formats: [:json], resource: deal
end
