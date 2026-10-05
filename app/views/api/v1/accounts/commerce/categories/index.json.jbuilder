json.payload @categories do |category|
  json.call(category, :id, :name, :position)
end
