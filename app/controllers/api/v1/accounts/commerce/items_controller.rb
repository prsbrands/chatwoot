class Api::V1::Accounts::Commerce::ItemsController < Api::V1::Accounts::Commerce::BaseController
  before_action :fetch_item, only: [:show, :update, :destroy, :add_image, :remove_image]
  before_action -> { check_authorization(@item || ::Commerce::Item) }

  # Filtros: kind (product/service), category_id e q (nome, código ou descrição).
  def index
    @items = Current.account.commerce_items.includes(:category, images_attachments: :blob).order(:position, :name)
    @items = @items.where(kind: params[:kind]) if params[:kind].present?
    @items = @items.where(category_id: params[:category_id]) if params[:category_id].present?
    @items = ::Commerce::Search.where(@items, %w[name sku description], params[:q]) if params[:q].present?
  end

  def show
    render :show
  end

  def create
    @item = Current.account.commerce_items.create!(item_params)
    render :show
  end

  def update
    @item.update!(item_params)
    render :show
  end

  def destroy
    @item.destroy!
    head :ok
  end

  def add_image
    @item.images.attach(blob_for(params.require(:blob_id)))
    @item.save!
    render :show
  end

  def remove_image
    @item.images.find(params.require(:attachment_id)).purge_later
    @item.reload
    render :show
  end

  private

  def fetch_item
    @item = Current.account.commerce_items.find(params[:id])
  end

  # Preço em branco = sob orçamento. A categoria tem que ser da conta.
  def item_params
    params.permit(:kind, :name, :description, :sku, :price, :currency, :unit, :available, :position, :category_id).tap do |permitted|
      permitted[:price] = nil if permitted.key?(:price) && permitted[:price].blank?
      Current.account.commerce_categories.find(permitted[:category_id]) if permitted[:category_id].present?
    end
  end
end
