# Leva o compromisso para o Google do responsável. Também tira o evento da
# agenda antiga quando o compromisso some ou muda de responsável
# (`previous_connection_id` é a conexão onde ele estava até agora).
class Agenda::GooglePushJob < ApplicationJob
  queue_as :low

  def perform(appointment_id, previous_connection_id)
    appointment = ::Agenda::Appointment.find_by(id: appointment_id)
    connection = appointment&.owner_id && ::Agenda::GoogleConnection.find_by(account_id: appointment.account_id, user_id: appointment.owner_id)
    remove_from_previous(appointment_id, previous_connection_id) if previous_connection_id && previous_connection_id != connection&.id
    return unless connection&.healthy?

    push(appointment, connection)
  end

  private

  def remove_from_previous(appointment_id, previous_connection_id)
    previous = ::Agenda::GoogleConnection.find_by(id: previous_connection_id)
    ::Agenda::GoogleCalendar.new(previous).delete_event("cgchat#{appointment_id}") if previous&.healthy?
  rescue ::Agenda::GoogleCalendar::Error => e
    Rails.logger.warn("[AGENDA] could not remove event cgchat#{appointment_id} from connection #{previous_connection_id}: #{e.message}")
  end

  # update_columns: gravar o resultado não pode disparar o after_commit e
  # mandar o compromisso de novo ao Google.
  # rubocop:disable Rails/SkipsModelValidations
  def push(appointment, connection)
    event = ::Agenda::GoogleCalendar.new(connection).upsert_event(appointment)
    appointment.update_columns(google_connection_id: connection.id, google_event_id: appointment.google_event_key,
                               google_synced_at: Time.current, google_sync_error: nil,
                               meeting_url: event['hangoutLink'].presence || appointment.meeting_url)
  rescue ::Agenda::GoogleCalendar::Error => e
    appointment.update_columns(google_sync_error: e.message.truncate(250))
  end
  # rubocop:enable Rails/SkipsModelValidations
end
