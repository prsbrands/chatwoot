class Api::V1::Accounts::Cases::TypesController < Api::V1::Accounts::Cases::BaseController
  before_action :fetch_type, only: [:update, :destroy]
  before_action -> { check_authorization(@type || ::Cases::Type) }

  # Ativos e inativos, na ordem da conta (a conta sem tipos ganha o modelo).
  def index
    @types = ::Cases::Type.for(Current.account)
  end

  def create
    @type = Current.account.cases_types.create!(type_params.with_defaults(position: Current.account.cases_types.maximum(:position).to_i + 1))
    render :show
  end

  def update
    @type.update!(type_params)
    render :show
  end

  # Tipo com caso não se apaga (422): desativa.
  def destroy
    raise ActiveRecord::RecordInvalid, @type unless @type.destroy

    head :ok
  end

  private

  def fetch_type
    @type = Current.account.cases_types.find(params[:id])
  end

  def type_params
    @type_params ||= params.permit(
      :name, :color, :position, :active, :sla_hours, :default_priority, :default_assignee_id, :default_team_id,
      :ai_mode, :ai_instructions, :notify_customer, fields: [:key, :label, :type, :required, { options: [] }]
    ).tap do |permitted|
      Current.account.users.find(permitted[:default_assignee_id]) if permitted[:default_assignee_id].present?
      Current.account.teams.find(permitted[:default_team_id]) if permitted[:default_team_id].present?
      permitted[:fields] = permitted[:fields].map(&:to_h) if permitted.key?(:fields)
    end
  end
end
