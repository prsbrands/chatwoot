json.id resource.id
json.pipeline_id resource.pipeline_id
json.stage_id resource.stage_id
json.status resource.status
json.title resource.title
json.value_cents resource.value_cents
json.currency resource.currency
json.lost_reason resource.lost_reason
json.stage_changed_at resource.stage_changed_at.to_i
json.closed_at resource.closed_at&.to_i
json.created_at resource.created_at.to_i
json.suggested_stage_id resource.suggested_stage_id
json.suggested_confidence resource.suggested_confidence
json.contact do
  json.id resource.contact.id
  json.name resource.contact.name
  json.phone_number resource.contact.phone_number
  json.thumbnail resource.contact.avatar_url
end
# display_id: e o id que o painel usa na URL da conversa.
json.conversation_id resource.conversation&.display_id
if resource.assignee
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.available_name
  end
end
