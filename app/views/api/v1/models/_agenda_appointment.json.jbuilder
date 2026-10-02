json.id resource.id
json.title resource.title
json.notes resource.notes
json.location resource.location
json.starts_at resource.starts_at.to_i
json.ends_at resource.ends_at.to_i
json.status resource.status
json.event_type_id resource.event_type_id
json.cancellation_reason resource.cancellation_reason
json.created_by_id resource.created_by_id
json.google_synced_at resource.google_synced_at&.to_i
json.google_sync_error resource.google_sync_error
json.conversation_id resource.conversation&.display_id
if resource.owner
  json.owner do
    json.id resource.owner.id
    json.name resource.owner.available_name
  end
end
if resource.contact
  json.contact do
    json.id resource.contact.id
    json.name resource.contact.name
  end
end
if resource.deal
  json.deal do
    json.id resource.deal.id
    json.title resource.deal.title
    json.stage_name resource.deal.stage.name
  end
end
