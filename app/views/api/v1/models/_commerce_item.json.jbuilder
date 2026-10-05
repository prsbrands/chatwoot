json.id resource.id
json.kind resource.kind
json.name resource.name
json.description resource.description
json.sku resource.sku
json.price resource.price&.to_s
json.currency resource.currency
json.unit resource.unit
json.available resource.available
json.position resource.position
json.category_id resource.category_id
json.category_name resource.category&.name
json.images resource.images do |image|
  json.id image.id
  json.url url_for(image)
  json.filename image.filename.to_s
end
