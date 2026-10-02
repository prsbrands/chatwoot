# Volta do consentimento do Google (GET /google_calendar/callback). O `state` é
# o AccountUser de quem clicou em "Conectar Google", assinado por 10 minutos:
# a conexão nasce dessa pessoa nessa conta, não de quem estiver logado.
class GoogleCalendar::CallbacksController < ApplicationController
  def show
    account_user = GlobalID::Locator.locate_signed(params[:state].to_s, for: 'google_calendar')
    return redirect_to('/') if account_user.nil?

    @account_id = account_user.account_id
    return back_to_agenda(params[:error] == 'access_denied' ? 'denied' : 'failed') if params[:code].blank?

    connect!(account_user)
    back_to_agenda('connected')
  rescue OAuth2::Error, ::Agenda::GoogleCalendar::Error, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[AGENDA] Google connection failed for account #{@account_id}: #{e.message}")
    back_to_agenda(e.is_a?(MissingScope) ? 'missing_scope' : 'failed')
  end

  private

  class MissingScope < ::Agenda::GoogleCalendar::Error; end

  def connect!(account_user)
    token = ::Agenda::GoogleCalendar.oauth_client.auth_code.get_token(params[:code], redirect_uri: ::Agenda::GoogleCalendar.redirect_uri)
    ensure_scopes!(token)
    connection = ::Agenda::GoogleConnection.find_or_initialize_by(account_id: account_user.account_id, user_id: account_user.user_id)
    store_token(connection, token)
    connection.email = ::Agenda::GoogleCalendar.new(connection).primary_email
    connection.save!
  end

  # A pessoa pode desmarcar permissões na tela do Google.
  def ensure_scopes!(token)
    granted = token.params['scope'].to_s.split
    raise MissingScope, 'calendar scopes not granted' unless (::Agenda::GoogleCalendar::SCOPES - granted).empty?
  end

  def store_token(connection, token)
    connection.assign_attributes(access_token: token.token, token_expires_at: Time.zone.at(token.expires_at),
                                 refresh_token: token.refresh_token.presence || connection.refresh_token,
                                 status: :healthy, last_error: nil)
    # Sem refresh_token a conexão morreria em uma hora sem aviso; o prompt
    # "consent" do pedido faz o Google mandar sempre.
    raise ::Agenda::GoogleCalendar::Error, 'Google sent no refresh token' if connection.refresh_token.blank?
  end

  def back_to_agenda(result)
    redirect_to "/app/accounts/#{@account_id}/agenda?google=#{result}"
  end
end
