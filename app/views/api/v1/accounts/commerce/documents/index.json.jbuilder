json.payload @documents do |document|
  json.partial! 'api/v1/models/commerce_document', formats: [:json], resource: document
end
json.meta do
  json.current_page @documents.current_page
  json.total_pages @documents.total_pages
  json.total_count @documents.total_count
end
