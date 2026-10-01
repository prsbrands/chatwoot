# Funis da conta. O padrao (onde nasce o negocio automatico) e criado na
# primeira leitura; admin cria outros, renomeia, troca o padrao e apaga os vazios.
class Api::V1::Accounts::Sales::PipelinesController < Api::V1::Accounts::Sales::BaseController
  before_action -> { check_authorization(::Sales::Pipeline) }
  before_action :fetch_pipeline, only: [:update, :destroy]

  def index
    default_pipeline
    @pipelines = Current.account.sales_pipelines.includes(:stages).order(:position, :id)
  end

  def create
    @pipeline = ::Sales::Pipeline.create_with_template!(Current.account, name: params.require(:name))
    render :update
  end

  def update
    @pipeline.update!(params.permit(:name))
    @pipeline.make_default! if ActiveModel::Type::Boolean.new.cast(params[:is_default])
  end

  # So funil vazio e que nao seja o padrao: negocio nao some junto com o funil.
  def destroy
    if @pipeline.is_default || @pipeline.deals.exists?
      return render json: { error: I18n.t('errors.sales.pipeline_not_empty') }, status: :unprocessable_entity
    end

    @pipeline.destroy!
    head :ok
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.sales_pipelines.find(params[:id])
  end
end
