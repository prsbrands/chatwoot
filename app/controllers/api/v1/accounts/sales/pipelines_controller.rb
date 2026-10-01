# Um funil por conta por enquanto: o padrao, criado na primeira leitura.
class Api::V1::Accounts::Sales::PipelinesController < Api::V1::Accounts::Sales::BaseController
  before_action -> { check_authorization(::Sales::Pipeline) }

  def index
    default_pipeline
    @pipelines = Current.account.sales_pipelines.includes(:stages).order(:position, :id)
  end

  def update
    @pipeline = Current.account.sales_pipelines.find(params[:id])
    @pipeline.update!(params.permit(:name))
  end
end
