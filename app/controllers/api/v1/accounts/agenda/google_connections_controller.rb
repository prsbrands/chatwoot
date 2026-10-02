# A conexão da pessoa logada com o Google Calendar, nesta conta: ver, conectar
# (ou trocar de conta Google) e desconectar. Qualquer pessoa da conta conecta a
# própria agenda.
#
# Desconectar não revoga o acesso no Google: o cliente OAuth é o mesmo do CRM,
# e revogar o token derruba a concessão inteira, inclusive a do CRM.
class Api::V1::Accounts::Agenda::GoogleConnectionsController < Api::V1::Accounts::BaseController
  def show
    render_connection
  end

  def create
    unless ::Agenda::GoogleCalendar.configured?
      return render json: { error: I18n.t('errors.agenda.google_not_configured') }, status: :unprocessable_entity
    end

    url = ::Agenda::GoogleCalendar.oauth_client.auth_code.authorize_url(
      redirect_uri: ::Agenda::GoogleCalendar.redirect_uri,
      scope: ::Agenda::GoogleCalendar::SCOPES.join(' '),
      access_type: 'offline',
      # consent: o Google só manda refresh_token quando pede o consentimento.
      prompt: 'consent select_account',
      include_granted_scopes: 'true',
      login_hint: Current.user.email,
      state: Current.account_user.to_sgid(expires_in: 10.minutes, for: 'google_calendar').to_s
    )
    render json: { url: url }
  end

  def destroy
    connection&.destroy!
    render_connection
  end

  private

  def connection
    @connection ||= Current.account.agenda_google_connections.find_by(user: Current.user)
  end

  def render_connection
    render json: {
      configured: ::Agenda::GoogleCalendar.configured?,
      connection: connection && connection.slice(:email, :status, :last_error, :updated_at)
    }
  end
end
