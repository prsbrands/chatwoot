# Horários livres de uma pessoa para um tipo de agendamento, entre `from` e
# `to` (o horarios-livres.ts do CRM):
# - só dentro da jornada da pessoa, no fuso dela;
# - a partir de agora + antecedência mínima, até agora + janela do tipo;
# - de duração em duração (consulta de 60 min às 9h, 10h…);
# - o horário, inflado pelas folgas antes e depois, não pode cruzar um
#   compromisso pendente/confirmado da pessoa nem o ocupado do Google dela.
# Google fora do ar não impede a resposta: `google_unavailable` avisa que o
# ocupado de lá ficou de fora.
class Agenda::FreeSlots
  Result = Struct.new(:slots, :google_unavailable, keyword_init: true)

  def initialize(event_type:, owner:, from:, to:)
    @event_type = event_type
    @owner = owner
    @availability = ::Agenda::Availability.find_by(account_id: event_type.account_id, user_id: owner.id)
    @from = [from, Time.current + event_type.minimum_notice_minutes.minutes].max
    @to = [to, Time.current + event_type.booking_window_days.days].min
  end

  def call
    return Result.new(slots: [], google_unavailable: false) if @availability.nil? || @from >= @to

    slots = days.flat_map { |date| @availability.windows_on(date).flat_map { |start, finish| slots_in(start, finish) } }
    Result.new(slots: slots.uniq.sort, google_unavailable: @google_unavailable || false)
  end

  private

  def duration
    @event_type.duration_minutes.minutes
  end

  def days
    (@from.in_time_zone(@availability.zone).to_date..@to.in_time_zone(@availability.zone).to_date).to_a
  end

  def slots_in(start, finish)
    slots = []
    slot = start
    while slot + duration <= finish
      slots << slot if slot.between?(@from, @to) && free?(slot)
      slot += duration
    end
    slots
  end

  def free?(slot)
    taken_from = slot - @event_type.buffer_before_minutes.minutes
    taken_to = slot + duration + @event_type.buffer_after_minutes.minutes
    busy.none? { |starts_at, ends_at| starts_at < taken_to && ends_at > taken_from }
  end

  def busy
    @busy ||= appointment_busy + google_busy
  end

  def margin
    (@event_type.buffer_before_minutes + @event_type.buffer_after_minutes + @event_type.duration_minutes).minutes
  end

  def appointment_busy
    ::Agenda::Appointment.where(account_id: @event_type.account_id, owner_id: @owner.id, status: %i[pending confirmed])
                         .between(@from - margin, @to + margin).pluck(:starts_at, :ends_at)
  end

  def google_busy
    connection = ::Agenda::GoogleConnection.healthy.find_by(account_id: @event_type.account_id, user_id: @owner.id)
    return [] unless connection

    ::Agenda::GoogleCalendar.new(connection).busy(@from - margin, @to + margin).map { |block| [block[:starts_at], block[:ends_at]] }
  rescue ::Agenda::GoogleCalendar::Error
    @google_unavailable = true
    []
  end
end
