class Api::V1::Accounts::Sales::Pipelines::StagesController < Api::V1::Accounts::Sales::BaseController
  before_action -> { check_authorization(::Sales::Stage) }
  before_action :fetch_pipeline

  def create
    @stage = @pipeline.stages.create!(stage_params.merge(account: Current.account))
  end

  def update
    @stage = @pipeline.stages.find(params[:id])
    @stage.update!(stage_params)
  end

  # Etapa com negocio dentro nao sai (restrict_with_error): mova os negocios antes.
  def destroy
    stage = @pipeline.stages.find(params[:id])
    return head :ok if stage.destroy

    render json: { error: stage.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.sales_pipelines.find(params[:pipeline_id])
  end

  def stage_params
    params.permit(:name, :position, :kind, :expected_duration_hours, :requires_human, :agent_step)
  end
end
