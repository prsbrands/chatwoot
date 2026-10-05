class Api::V1::Accounts::Commerce::PaymentMethodsController < Api::V1::Accounts::Commerce::BaseController
  before_action :fetch_payment_method, only: [:update, :destroy]
  before_action -> { check_authorization(@payment_method || ::Commerce::PaymentMethod) }

  def index
    @payment_methods = Current.account.commerce_payment_methods.order(:position, :name)
  end

  def create
    @payment_method = Current.account.commerce_payment_methods.create!(payment_method_params)
    render :show
  end

  def update
    @payment_method.update!(payment_method_params)
    render :show
  end

  def destroy
    @payment_method.destroy!
    head :ok
  end

  private

  def fetch_payment_method
    @payment_method = Current.account.commerce_payment_methods.find(params[:id])
  end

  def payment_method_params
    params.permit(:name, :kind, :instructions, :active, :position)
  end
end
