json.payload @tasks do |task|
  json.partial! 'api/v1/models/sales_task', formats: [:json], resource: task
end
