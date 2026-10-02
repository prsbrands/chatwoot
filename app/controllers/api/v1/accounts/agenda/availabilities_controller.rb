# A jornada de cada pessoa da conta. PUT /availabilities/:id, com o id da
# pessoa, cria ou troca a jornada dela.
class Api::V1::Accounts::Agenda::AvailabilitiesController < Api::V1::Accounts::BaseController
  def index
    authorize ::Agenda::Availability
    @availabilities = Current.account.agenda_availabilities
  end

  def update
    @availability = Current.account.agenda_availabilities.find_or_initialize_by(user: Current.account.users.find(params[:id]))
    authorize @availability
    @availability.update!(time_zone: params.require(:time_zone), windows: windows_param)
    render :show
  end

  private

  def windows_param
    params.permit(windows: [:day, :start, :end])[:windows].to_a.map do |window|
      { 'day' => window[:day].to_i, 'start' => window[:start].to_s, 'end' => window[:end].to_s }
    end
  end
end
