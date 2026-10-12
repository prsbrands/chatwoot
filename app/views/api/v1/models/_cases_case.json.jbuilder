json.id resource.id
json.number resource.number
json.title resource.title
json.description resource.description
json.status resource.status
json.priority resource.priority
json.source resource.source
json.outcome resource.outcome
json.resolution resource.resolution
json.due_at resource.due_at&.to_i
json.paused_at resource.paused_at&.to_i
json.overdue resource.overdue?
json.field_values resource.field_values
json.resolved_at resource.resolved_at&.to_i
json.canceled_at resource.canceled_at&.to_i
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
json.type do
  json.id resource.type.id
  json.name resource.type.name
  json.color resource.type.color
end
json.team_id resource.team_id
json.deal_id resource.deal_id
if resource.assignee
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.available_name
    json.thumbnail resource.assignee.avatar_url
  end
end
json.contact do
  json.id resource.contact.id
  json.name resource.contact.name
  json.thumbnail resource.contact.avatar_url
end
