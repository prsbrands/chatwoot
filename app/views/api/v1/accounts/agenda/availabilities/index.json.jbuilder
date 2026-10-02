json.payload @availabilities do |availability|
  json.call(availability, :user_id, :time_zone, :windows)
end
