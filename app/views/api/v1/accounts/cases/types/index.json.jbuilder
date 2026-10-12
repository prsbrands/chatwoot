json.payload @types do |type|
  json.partial! 'api/v1/models/cases_type', formats: [:json], resource: type
end
