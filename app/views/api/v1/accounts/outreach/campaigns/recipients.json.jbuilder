json.payload @recipients do |recipient|
  json.id recipient.id
  json.phone recipient.phone
  json.name recipient.name
  json.status recipient.status
  json.excluded_reason recipient.excluded_reason
  json.error recipient.error
  json.variant recipient.variant
  json.conversation_id recipient.conversation_id
  json.sent_at recipient.sent_at&.to_i
  json.replied_at recipient.replied_at&.to_i
end
json.meta do
  json.count @count
  json.page @page
end
