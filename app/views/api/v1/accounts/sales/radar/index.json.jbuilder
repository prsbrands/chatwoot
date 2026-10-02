json.counts do
  Sales::Radar::BUCKETS.each { |bucket| json.set! bucket, (@rows.count { |row| row[:bucket] == bucket }) }
end
json.payload @rows do |row|
  json.bucket row[:bucket]
  json.last_activity_at row[:last_activity_at]
  json.followup_at row[:followup_at]
  json.owner row[:owner]
  json.deal do
    json.partial! 'api/v1/models/sales_deal', formats: [:json], resource: row[:deal]
    json.pipeline_name row[:deal].pipeline.name
    json.stage_name row[:deal].stage.name
  end
end
