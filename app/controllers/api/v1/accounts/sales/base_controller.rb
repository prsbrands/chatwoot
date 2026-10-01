# Funil de vendas (bloco 3a). Dentro deste namespace `Sales` e o modulo do
# controller: os models sao sempre `::Sales::...`.
class Api::V1::Accounts::Sales::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_sales_pipeline_enabled!

  private

  def ensure_sales_pipeline_enabled!
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('sales_pipeline')
  end

  def default_pipeline
    @default_pipeline ||= ::Sales::Pipeline.default_for(Current.account)
  end
end
