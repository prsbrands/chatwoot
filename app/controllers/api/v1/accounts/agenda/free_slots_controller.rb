# Horários livres para marcar um tipo de agendamento com uma pessoa (owner_id,
# ou quem atende por padrão no tipo, ou quem pede), num dia (date, no fuso da
# pessoa) ou entre from/to.
class Api::V1::Accounts::Agenda::FreeSlotsController < Api::V1::Accounts::BaseController
  def index
    authorize ::Agenda::Appointment
    event_type = Current.account.agenda_event_types.find(params.require(:event_type_id))
    owner = params[:owner_id].present? ? Current.account.users.find(params[:owner_id]) : event_type.default_owner || Current.user
    from, to = range_for(owner)
    @result = ::Agenda::FreeSlots.new(event_type: event_type, owner: owner, from: from, to: to).call
    @owner = owner
  end

  private

  def range_for(owner)
    if params[:date].present?
      zone = ::Agenda::Availability.find_by(account: Current.account, user: owner)&.zone || Time.zone
      day = zone.parse(params[:date])
      raise ActionController::BadRequest, 'invalid date' if day.nil?

      [day.beginning_of_day, day.end_of_day]
    else
      [Time.zone.iso8601(params.require(:from)), Time.zone.iso8601(params.require(:to))]
    end
  rescue ArgumentError
    raise ActionController::BadRequest, 'invalid range'
  end
end
