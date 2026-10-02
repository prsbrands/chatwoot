json.id resource.id
json.title resource.title
json.notes resource.notes
json.due_at resource.due_at&.to_i
json.completed_at resource.completed_at&.to_i
json.created_by_id resource.created_by_id
json.created_at resource.created_at.to_i
if resource.assignee
  json.assignee do
    json.id resource.assignee.id
    json.name resource.assignee.available_name
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
    # display_id: o id que o painel usa na URL da conversa.
    json.conversation_id resource.deal.conversation&.display_id
  end
end
