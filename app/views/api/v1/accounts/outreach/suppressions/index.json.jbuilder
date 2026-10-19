json.payload @suppressions do |suppression|
  json.id suppression.id
  json.phone suppression.phone
  json.reason suppression.reason
  json.created_at suppression.created_at.to_i
end
