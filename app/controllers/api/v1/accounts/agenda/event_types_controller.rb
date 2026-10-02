class Api::V1::Accounts::Agenda::EventTypesController < Api::V1::Accounts::BaseController
  before_action :fetch_event_type, only: [:update, :destroy]
  before_action -> { check_authorization(@event_type || ::Agenda::EventType) }

  def index
    @event_types = Current.account.agenda_event_types.includes(:default_owner).order(:name)
  end

  def create
    @event_type = Current.account.agenda_event_types.create!(event_type_params)
    render :show
  end

  def update
    @event_type.update!(event_type_params)
    render :show
  end

  def destroy
    @event_type.destroy!
    head :ok
  end

  private

  def fetch_event_type
    @event_type = Current.account.agenda_event_types.find(params[:id])
  end

  # Quem atende por padrão tem que ser da conta.
  def event_type_params
    @event_type_params ||= params.permit(:name, :duration_minutes, :buffer_before_minutes, :buffer_after_minutes,
                                         :minimum_notice_minutes, :booking_window_days, :location, :default_owner_id,
                                         :requires_confirmation, :active).tap do |permitted|
      Current.account.users.find(permitted[:default_owner_id]) if permitted[:default_owner_id].present?
    end
  end
end
