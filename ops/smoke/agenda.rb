# Agenda (Agenda::Appointment, /agenda/appointments, /agenda/google_connection,
# /google_calendar/callback e o envio ao Google) contra Postgres/Redis
# descartaveis. O Google e falso: as chamadas ficam em CALLS.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

CALLS = []
BUSY = {}
Agenda::GoogleCalendar.class_eval do
  def primary_email = 'ana@gmail.test'
  def upsert_event(appointment)
    CALLS << [:upsert, @connection.id, appointment.google_event_key, appointment.status]
    { 'id' => appointment.google_event_key }
  end
  def delete_event(key) = CALLS << [:delete, @connection.id, key]

  def busy(_from, _to)
    raise Agenda::GoogleCalendar::Error, 'Google fora do ar' if BUSY[@connection.id] == :error

    BUSY.fetch(@connection.id, [])
  end
end

account = Account.create!(name: 'Agenda', locale: 'es')
account.enable_features!('sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@agenda.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
beto = User.create!(name: 'Beto', email: "beto-#{SecureRandom.hex(3)}@agenda.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
AccountUser.create!(account: account, user: beto, role: :agent)
inbox = account.inboxes.create!(name: 'Site', channel: Channel::Api.create!(account: account))
contact = account.contacts.create!(name: 'Cliente Agenda')
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversation = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
deal = Sales::Deal.open_for_contact!(contact, conversation: conversation)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/agenda/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

# --- conexao com o Google ---------------------------------------------------
st, body = api.(ana, :get, 'google_connection')
ok 'sem app OAuth: configured false', st == 200 && body['configured'] == false && body['connection'].nil?
ok 'conectar sem app OAuth: 422', api.(ana, :post, 'google_connection').first == 422

InstallationConfig.where(name: %w[GOOGLE_CALENDAR_CLIENT_ID GOOGLE_CALENDAR_CLIENT_SECRET]).delete_all
InstallationConfig.create!(name: 'GOOGLE_CALENDAR_CLIENT_ID', value: 'cliente.apps.googleusercontent.com', locked: false)
InstallationConfig.create!(name: 'GOOGLE_CALENDAR_CLIENT_SECRET', value: 'segredo-de-teste', locked: false)
GlobalConfig.clear_cache
st, body = api.(ana, :post, 'google_connection')
url = URI(body['url'])
query = Rack::Utils.parse_query(url.query)
ok 'conectar: URL do Google com offline, consent e redirect certo', st == 200 && url.host == 'accounts.google.com' &&
                                                                   query['access_type'] == 'offline' && query['prompt'].include?('consent') &&
                                                                   query['redirect_uri'].end_with?('/google_calendar/callback') &&
                                                                   query['scope'].include?('calendar.events')

s.get '/google_calendar/callback', params: { state: 'falso', code: 'x' }
ok 'callback com state falso: volta para a raiz', s.response.redirect? && s.response.location.end_with?('/')

token = Struct.new(:token, :refresh_token, :expires_at, :params)
FAKE_TOKEN = token.new('acesso-1', 'renova-1', 1.hour.from_now.to_i,
                       { 'scope' => Agenda::GoogleCalendar::SCOPES.join(' ') })
fake_client = Object.new
def fake_client.auth_code = self
def fake_client.get_token(_code, **) = FAKE_TOKEN
Agenda::GoogleCalendar.define_singleton_method(:oauth_client) { fake_client }

s.get '/google_calendar/callback', params: { state: query['state'], code: 'codigo' }
conexao = Agenda::GoogleConnection.find_by(account: account, user: ana)
ok 'callback: conexao da Ana gravada, de volta na Agenda', s.response.location.end_with?("/app/accounts/#{account.id}/agenda?google=connected") &&
                                                           conexao&.email == 'ana@gmail.test' && conexao.healthy?
cru = ActiveRecord::Base.connection.select_value("SELECT refresh_token FROM agenda_google_connections WHERE id = #{conexao.id}")
ok 'refresh_token cifrado no banco', conexao.refresh_token == 'renova-1' && (!Chatwoot.encryption_configured? || cru != 'renova-1')

s.get '/google_calendar/callback', params: { state: query['state'], error: 'access_denied' }
ok 'pessoa recusou no Google', s.response.location.end_with?('agenda?google=denied')

parcial = token.new('a', 'r', 1.hour.from_now.to_i, { 'scope' => 'https://www.googleapis.com/auth/calendar.readonly' })
def fake_client.get_token(_code, **) = PARCIAL
PARCIAL = parcial
s.get '/google_calendar/callback', params: { state: query['state'], code: 'codigo' }
ok 'permissao incompleta: avisa e nao troca a conexao', s.response.location.end_with?('agenda?google=missing_scope') &&
                                                       Agenda::GoogleConnection.find(conexao.id).access_token == 'acesso-1'

# --- compromissos ----------------------------------------------------------
inicio = 1.day.from_now.change(hour: 15)
st, a1 = api.(ana, :post, 'appointments', { title: 'Demo', starts_at: inicio.iso8601, ends_at: (inicio + 1.hour).iso8601,
                                            deal_id: deal.id, conversation_id: conversation.display_id })
ok 'marcar: 200, dona = quem marcou, contato do negocio', st == 200 && a1.dig('owner', 'id') == ana.id && a1.dig('contact', 'id') == contact.id &&
                                                         a1['conversation_id'] == conversation.display_id && a1['status'] == 'confirmed'
ok 'fim antes do inicio: 422', api.(ana, :post, 'appointments', { title: 'X', starts_at: inicio.iso8601, ends_at: inicio.iso8601 }).first == 422
ok 'status invalido: 422', api.(ana, :patch, "appointments/#{a1['id']}", { status: 'talvez' }).first == 422

Agenda::GooglePushJob.perform_now(a1['id'], nil)
compromisso = Agenda::Appointment.find(a1['id'])
ok 'envio ao Google da dona', CALLS.last == [:upsert, conexao.id, "cgchat#{a1['id']}", 'confirmed'] &&
                              compromisso.google_connection_id == conexao.id && compromisso.google_synced_at.present?

CALLS.clear
compromisso.update!(owner: beto)
Agenda::GooglePushJob.perform_now(compromisso.id, conexao.id)
ok 'mudou para quem nao tem Google: sai da agenda da Ana, nao vai para lugar nenhum', CALLS == [[:delete, conexao.id, "cgchat#{compromisso.id}"]]

compromisso.update!(owner: ana)
CALLS.clear
Agenda::GooglePushJob.perform_now(compromisso.id, nil)
id_apagado = compromisso.id
compromisso.destroy!
Agenda::GooglePushJob.perform_now(id_apagado, conexao.id)
ok 'apagar o compromisso apaga o evento', CALLS.last == [:delete, conexao.id, "cgchat#{id_apagado}"]

# --- grade e ocupado do Google ----------------------------------------------
_, a2 = api.(ana, :post, 'appointments', { title: 'Visita', starts_at: inicio.iso8601, ends_at: (inicio + 30.minutes).iso8601 })
_, a3 = api.(beto, :post, 'appointments', { title: 'Ligacao', starts_at: (inicio + 2.hours).iso8601, ends_at: (inicio + 3.hours).iso8601 })
api.(ana, :post, 'appointments', { title: 'Mes que vem', starts_at: 40.days.from_now.iso8601, ends_at: (40.days.from_now + 1.hour).iso8601 })
BUSY[conexao.id] = [{ starts_at: inicio - 2.hours, ends_at: inicio - 1.hour, all_day: false }]
faixa = "from=#{CGI.escape(inicio.beginning_of_day.iso8601)}&to=#{CGI.escape(inicio.end_of_day.iso8601)}"
_, minha = api.(ana, :get, "appointments?#{faixa}&owner_id=me")
ok 'minha agenda: so os da Ana no dia, com o ocupado do Google dela', minha['payload'].map { |a| a['id'] } == [a2['id']] &&
                                                                      minha['busy'].size == 1 && minha['busy'][0]['owner_id'] == ana.id
_, equipe = api.(beto, :get, "appointments?#{faixa}&owner_id=all")
ok 'agenda da equipe', equipe['payload'].map { |a| a['id'] }.sort == [a2['id'], a3['id']].sort
Rails.cache.clear
BUSY[conexao.id] = :error
_, fora = api.(ana, :get, "appointments?#{faixa}&owner_id=me")
ok 'Google fora do ar nao derruba a Agenda', fora['payload'].size == 1 && fora['busy'].empty? && fora['google_errors'].size == 1
ok 'data invalida: 400', api.(ana, :get, 'appointments?from=ontem&to=hoje').first == 400

_, do_negocio = api.(ana, :get, "appointments?deal_id=#{deal.id}")
ok 'proximos do negocio (o apagado nao volta)', do_negocio['payload'].empty?

# --- permissao, radar e contato ---------------------------------------------
ok 'Beto nao apaga compromisso da Ana: 401', api.(beto, :delete, "appointments/#{a2['id']}").first == 401
ok 'Beto apaga o proprio', api.(beto, :delete, "appointments/#{a3['id']}").first == 200

ok 'radar: negocio sem tarefa nem compromisso', Sales::Radar.new(account).without_next_step.map(&:id) == [deal.id]
api.(ana, :post, 'appointments', { title: 'Retorno', deal_id: deal.id, starts_at: inicio.iso8601, ends_at: (inicio + 1.hour).iso8601 })
ok 'radar: compromisso marcado conta como proximo passo', Sales::Radar.new(account).without_next_step.none?
_, canc = api.(ana, :get, "appointments?deal_id=#{deal.id}")
api.(ana, :patch, "appointments/#{canc['payload'][0]['id']}", { status: 'cancelled' })
ok 'radar: compromisso cancelado nao conta', Sales::Radar.new(account).without_next_step.map(&:id) == [deal.id]

contact.destroy!
ok 'apagar o contato mantem o compromisso, sem contato', Agenda::Appointment.where(account: account).exists? &&
                                                       Agenda::Appointment.where(account: account, contact_id: contact.id).none?

st, = api.(ana, :delete, 'google_connection')
ok 'desconectar', st == 200 && !Agenda::GoogleConnection.exists?(conexao.id)
account.disable_features!('sales_pipeline')
ok 'Agenda nao depende da flag do funil', api.(ana, :get, "appointments?#{faixa}").first == 200
