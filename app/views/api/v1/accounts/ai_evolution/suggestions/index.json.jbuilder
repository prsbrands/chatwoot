json.payload @suggestions do |suggestion|
  json.partial! 'api/v1/models/ai_evolution_suggestion', formats: [:json], resource: suggestion
end
