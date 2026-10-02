json.owner_id @owner.id
json.slots(@result.slots.map(&:to_i))
json.google_unavailable @result.google_unavailable
