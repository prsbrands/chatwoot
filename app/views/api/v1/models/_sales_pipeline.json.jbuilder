json.id resource.id
json.name resource.name
json.is_default resource.is_default
json.stages resource.stages do |stage|
  json.partial! 'api/v1/models/sales_stage', formats: [:json], resource: stage
end
