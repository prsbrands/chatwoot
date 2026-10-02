# O Google Calendar de uma pessoa (Agenda::GoogleConnection): renova o token
# quando está para vencer, lê o que está ocupado e grava os compromissos como
# eventos na agenda principal. Um app OAuth por instalação (Super Admin →
# Settings → Google Calendar).
class Agenda::GoogleCalendar
  API = 'https://www.googleapis.com/calendar/v3'.freeze
  SCOPES = %w[https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/calendar.readonly].freeze
  # O Google devolve status 'cancelled' para evento cancelado; pendente vira
  # 'tentative' (aparece riscado na agenda da pessoa).
  EVENT_STATUS = { 'pending' => 'tentative', 'cancelled' => 'cancelled' }.freeze

  class Error < StandardError; end
  class AuthError < Error; end
  class NotFound < Error; end

  def self.configured?
    client_id.present? && GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_SECRET', nil).present?
  end

  def self.client_id
    GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_ID', nil)
  end

  def self.oauth_client
    ::OAuth2::Client.new(client_id, GlobalConfigService.load('GOOGLE_CALENDAR_CLIENT_SECRET', nil),
                         site: 'https://oauth2.googleapis.com',
                         authorize_url: 'https://accounts.google.com/o/oauth2/auth',
                         token_url: 'https://oauth2.googleapis.com/token')
  end

  def self.redirect_uri
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/google_calendar/callback"
  end

  def initialize(connection)
    @connection = connection
  end

  # O id da agenda principal é o e-mail da conta Google.
  def primary_email
    request(:get, '/calendars/primary')['id']
  end

  # Ocupado no Google: eventos opacos e não cancelados. Os que nasceram de um
  # compromisso daqui (id cgchat…) ficam de fora, para não aparecer em dobro.
  def busy(from, to)
    items = request(:get, '/calendars/primary/events',
                    query: { timeMin: from.iso8601, timeMax: to.iso8601, singleEvents: true, maxResults: 250,
                             fields: 'items(id,status,transparency,start,end)' })['items'] || []
    items.reject { |event| event['status'] == 'cancelled' || event['transparency'] == 'transparent' || event['id'].start_with?('cgchat') }
         .map { |event| { starts_at: event_time(event['start']), ends_at: event_time(event['end']), all_day: event['start'].key?('date') } }
  end

  # PATCH primeiro: o evento pode já existir (inclusive cancelado, que o PATCH
  # reativa). Só cria quando o Google não conhece o id.
  def upsert_event(appointment)
    body = event_body(appointment)
    request(:patch, "/calendars/primary/events/#{appointment.google_event_key}", body: body)
  rescue NotFound
    request(:post, '/calendars/primary/events', body: body.merge(id: appointment.google_event_key))
  end

  def delete_event(event_key)
    request(:delete, "/calendars/primary/events/#{event_key}")
  rescue NotFound
    nil
  end

  private

  def event_body(appointment)
    {
      summary: appointment.title,
      description: appointment.notes,
      location: appointment.location,
      start: { dateTime: appointment.starts_at.utc.iso8601 },
      end: { dateTime: appointment.ends_at.utc.iso8601 },
      status: EVENT_STATUS.fetch(appointment.status, 'confirmed')
    }
  end

  def event_time(value)
    Time.zone.parse(value['dateTime'] || value['date'])
  end

  def request(verb, path, query: nil, body: nil)
    response = HTTParty.public_send(verb, "#{API}#{path}", query: query, body: body&.to_json, timeout: 15,
                                                           headers: { 'Authorization' => "Bearer #{access_token}",
                                                                      'Content-Type' => 'application/json' })
    handle(response)
  end

  def handle(response)
    return response.parsed_response || {} if response.success?
    raise NotFound, "Google Calendar: #{response.code}" if [404, 410].include?(response.code)

    if response.code == 401
      @connection.update!(status: :reauthorization_required, last_error: 'Google rejected the access token')
      raise AuthError, 'Google rejected the access token'
    end
    raise Error, "Google Calendar: HTTP #{response.code} #{response.body.to_s.truncate(200)}"
  end

  def access_token
    refresh! if @connection.token_expires_at.nil? || @connection.token_expires_at < 1.minute.from_now
    @connection.access_token
  end

  # Sem refresh_token válido (revogado na conta Google, senha trocada), a pessoa
  # precisa conectar de novo: a conexão fica marcada e a Agenda avisa.
  def refresh!
    token = OAuth2::AccessToken.new(self.class.oauth_client, @connection.access_token,
                                    refresh_token: @connection.refresh_token).refresh!
    @connection.update!(access_token: token.token, token_expires_at: Time.zone.at(token.expires_at),
                        refresh_token: token.refresh_token.presence || @connection.refresh_token,
                        status: :healthy, last_error: nil)
  rescue OAuth2::Error => e
    @connection.update!(status: :reauthorization_required, last_error: e.message.truncate(250))
    raise AuthError, e.message
  end
end
