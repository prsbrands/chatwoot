# O que o bot do n8n usa para marcar na conversa (com o token de usuário da
# conta, o mesmo do nó Historico): os horários livres do tipo que a IA oferece
# e a marcação de um deles. Horário ocupado no meio do caminho volta 409 com
# as próximas opções.
class Api::V1::Accounts::Agenda::BotController < Api::V1::Accounts::BaseController
  before_action -> { authorize ::Agenda::Appointment, :create? }

  def slots
    booking = ::Agenda::AiBooking.new(Current.account)
    return render json: { available: false } if booking.event_type.nil?

    render json: {
      available: true,
      event_type: booking.event_type.slice(:id, :name, :duration_minutes),
      time_zone: booking.zone.tzinfo.name,
      slots: booking.slots.map { |slot| slot.in_time_zone(booking.zone).iso8601 }
    }
  end

  def book
    booking = ::Agenda::AiBooking.new(Current.account)
    raise ActionController::BadRequest, 'no AI bookable type' if booking.event_type.nil?

    @appointment = booking.book!(conversation, starts_at)
    render 'api/v1/accounts/agenda/appointments/show'
  rescue ::Agenda::AiBooking::SlotTaken => e
    render json: { error: 'slot_taken', time_zone: booking.zone.tzinfo.name,
                   alternatives: e.alternatives.map { |slot| slot.in_time_zone(booking.zone).iso8601 } },
           status: :conflict
  end

  private

  def conversation
    Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
  end

  def starts_at
    Time.zone.iso8601(params.require(:starts_at))
  rescue ArgumentError
    raise ActionController::BadRequest, 'invalid starts_at'
  end
end
