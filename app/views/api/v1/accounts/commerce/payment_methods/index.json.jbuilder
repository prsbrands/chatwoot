json.payload @payment_methods do |method|
  json.call(method, :id, :name, :kind, :instructions, :active, :position)
end
