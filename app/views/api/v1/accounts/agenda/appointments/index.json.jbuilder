json.payload @appointments do |appointment|
  json.partial! 'api/v1/models/agenda_appointment', formats: [:json], resource: appointment
end
json.busy @busy do |block|
  json.owner_id block[:owner_id]
  json.starts_at block[:starts_at].to_i
  json.ends_at block[:ends_at].to_i
  json.all_day block[:all_day]
end
json.google_errors @google_errors || []
