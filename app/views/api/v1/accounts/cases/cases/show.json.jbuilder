json.partial! 'api/v1/models/cases_case', formats: [:json], resource: @case
json.type_fields @case.type.fields
json.missing_required_fields @case.missing_required_fields.pluck('key')
if @case.deal
  json.deal do
    json.id @case.deal.id
    json.title @case.deal.title
  end
end
json.conversations @case.case_conversations.includes(conversation: :inbox).order(:created_at) do |link|
  json.id link.conversation.display_id
  json.origin link.origin
  json.inbox_name link.conversation.inbox.name
  json.status link.conversation.status
  json.last_activity_at link.conversation.last_activity_at&.to_i
end
json.events @case.events.includes(:actor) do |event|
  json.partial! 'api/v1/models/cases_event', formats: [:json], resource: event
end
