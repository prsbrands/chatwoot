class Api::V1::Accounts::Agenda::AppointmentsController < Api::V1::Accounts::BaseController
  MAX_RANGE = 62.days
  BUSY_CACHE = 2.minutes

  before_action :fetch_appointment, only: [:update, :destroy]
  before_action -> { check_authorization(@appointment || ::Agenda::Appointment) }

  # Um intervalo (from/to, ISO 8601) da agenda de uma pessoa (owner_id, ou "me")
  # ou da equipe inteira, com o que está ocupado no Google de cada responsável.
  # Por negócio ou contato, sem intervalo: os próximos compromissos.
  def index
    @appointments = scoped_appointments.includes(:owner, :contact, :conversation, deal: :stage).order(:starts_at)
    @busy = deal_or_contact? ? [] : google_busy
  end

  # Tipo que pede confirmação faz o compromisso nascer pendente.
  def create
    defaults = { owner_id: Current.user.id }
    defaults[:status] = :pending if event_type&.requires_confirmation
    @appointment = Current.account.agenda_appointments.create!(appointment_params.with_defaults(defaults).merge(created_by: Current.user))
    render :show
  end

  def update
    @appointment.update!(appointment_params)
    render :show
  end

  def destroy
    @appointment.destroy!
    head :ok
  end

  private

  def fetch_appointment
    @appointment = Current.account.agenda_appointments.find(params[:id])
  end

  def deal_or_contact?
    params[:deal_id].present? || params[:contact_id].present?
  end

  def scoped_appointments
    appointments = Current.account.agenda_appointments
    return appointments.where(deal_id: params[:deal_id]).where(starts_at: Time.current..) if params[:deal_id].present?
    return appointments.where(contact_id: params[:contact_id]).where(starts_at: Time.current..) if params[:contact_id].present?

    appointments = appointments.between(range_from, range_to)
    owner_ids ? appointments.where(owner_id: owner_ids) : appointments
  end

  def range_from
    @range_from ||= time_param(:from)
  end

  def range_to
    @range_to ||= [time_param(:to), range_from + MAX_RANGE].min
  end

  def time_param(key)
    Time.zone.iso8601(params.require(key))
  rescue ArgumentError
    raise ActionController::BadRequest, "invalid #{key}"
  end

  def owner_ids
    return nil if params[:owner_id].blank? || params[:owner_id] == 'all'

    [params[:owner_id] == 'me' ? Current.user.id : params[:owner_id].to_i]
  end

  # O Google de cada pessoa na tela. Uma conta Google fora do ar não derruba a
  # Agenda: a pessoa sai sem ocupado e o motivo vai junto (`google_errors`).
  def google_busy
    connections = Current.account.agenda_google_connections.healthy
    connections = connections.where(user_id: owner_ids) if owner_ids
    @google_errors = []
    connections.flat_map do |connection|
      blocks = Rails.cache.fetch(['agenda-busy', connection.id, range_from.to_i, range_to.to_i], expires_in: BUSY_CACHE) do
        ::Agenda::GoogleCalendar.new(connection).busy(range_from, range_to)
      end
      blocks.map { |block| block.merge(owner_id: connection.user_id) }
    rescue ::Agenda::GoogleCalendar::Error => e
      @google_errors << { owner_id: connection.user_id, error: e.message }
      []
    end
  end

  # Responsável, contato, negócio e conversa têm que ser da conta: o find levanta
  # 404 em vez de gravar o de outra conta. A conversa vem pelo display_id.
  def appointment_params
    @appointment_params ||= params.permit(:title, :notes, :location, :starts_at, :ends_at, :status, :cancellation_reason,
                                          :owner_id, :contact_id, :deal_id, :event_type_id).tap do |permitted|
      ensure_links_in_account!(permitted)
      if params[:conversation_id].present?
        permitted[:conversation_id] = Current.account.conversations.find_by!(display_id: params[:conversation_id]).id
      end
    end
  end

  def event_type
    @event_type ||= Current.account.agenda_event_types.find(params[:event_type_id]) if params[:event_type_id].present?
  end

  def ensure_links_in_account!(permitted)
    event_type if permitted[:event_type_id].present?
    Current.account.users.find(permitted[:owner_id]) if permitted[:owner_id].present?
    Current.account.contacts.find(permitted[:contact_id]) if permitted[:contact_id].present?
    Current.account.sales_deals.find(permitted[:deal_id]) if permitted[:deal_id].present?
  end
end
