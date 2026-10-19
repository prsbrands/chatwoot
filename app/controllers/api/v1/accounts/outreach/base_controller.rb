# Campanhas por QR (flag `outreach`). Dentro deste namespace `Outreach` é o
# módulo do controller: os models são sempre `::Outreach::...`.
class Api::V1::Accounts::Outreach::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_outreach_enabled!

  private

  def ensure_outreach_enabled!
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('outreach')
  end
end
