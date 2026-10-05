class Api::V1::Accounts::Commerce::CategoriesController < Api::V1::Accounts::Commerce::BaseController
  before_action :fetch_category, only: [:update, :destroy]
  before_action -> { check_authorization(@category || ::Commerce::Category) }

  def index
    @categories = Current.account.commerce_categories.order(:position, :name)
  end

  def create
    @category = Current.account.commerce_categories.create!(params.permit(:name, :position))
    render :show
  end

  def update
    @category.update!(params.permit(:name, :position))
    render :show
  end

  # Os itens ficam sem categoria.
  def destroy
    @category.destroy!
    head :ok
  end

  private

  def fetch_category
    @category = Current.account.commerce_categories.find(params[:id])
  end
end
