json.meta do
  json.total @total
  json.per_page Api::V1::Accounts::Cases::CasesController::PER_PAGE
end
json.payload @cases do |kase|
  json.partial! 'api/v1/models/cases_case', formats: [:json], resource: kase
end
