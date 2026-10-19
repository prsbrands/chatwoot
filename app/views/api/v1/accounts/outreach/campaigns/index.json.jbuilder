json.payload @campaigns do |campaign|
  json.partial! 'api/v1/models/outreach_campaign', formats: [:json], resource: campaign
end
