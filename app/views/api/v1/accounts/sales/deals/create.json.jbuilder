json.partial! 'api/v1/models/sales_deal', formats: [:json], resource: @deal
json.transitions @deal.transitions.includes(:actor).limit(50) do |transition|
  json.partial! 'api/v1/models/sales_deal_transition', formats: [:json], resource: transition
end
