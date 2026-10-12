# Casos (flag `cases`). Dentro deste namespace `Cases` é o módulo do
# controller: os models são sempre `::Cases::...`.
class Api::V1::Accounts::Cases::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_cases_enabled!

  private

  def ensure_cases_enabled!
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('cases')
  end
end
