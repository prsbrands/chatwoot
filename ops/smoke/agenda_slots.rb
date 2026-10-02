# Agenda, 2a parte: tipos de agendamento, jornada e horarios livres
# (Agenda::FreeSlots e /agenda/free_slots) contra Postgres/Redis descartaveis.
# O Google e falso: BUSY por conexao, ou :error.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

BUSY = {}
Agenda::GoogleCalendar.class_eval do
  def busy(_from, _to)
    raise Agenda::GoogleCalendar::Error, 'fora do ar' if BUSY[@connection.id] == :error

    BUSY.fetch(@connection.id, [])
  end
  def upsert_event(_appointment) = nil
end

account = Account.create!(name: 'Horarios', locale: 'es')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@slots.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
beto = User.create!(name: 'Beto', email: "beto-#{SecureRandom.hex(3)}@slots.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
AccountUser.create!(account: account, user: beto, role: :agent)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/agenda/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

seg_a_sex = (1..5).map { |day| { day: day, start: '09:00', end: '12:00' } }
ok 'jornada com faixa invertida: 422', api.(ana, :put, "availabilities/#{ana.id}", { time_zone: 'America/Bogota', windows: [{ day: 1, start: '12:00', end: '09:00' }] }).first == 422
ok 'fuso inexistente: 422', api.(ana, :put, "availabilities/#{ana.id}", { time_zone: 'Marte/Olimpo', windows: seg_a_sex }).first == 422
st, = api.(ana, :put, "availabilities/#{ana.id}", { time_zone: 'America/Bogota', windows: seg_a_sex })
ok 'jornada da Ana: seg a sex, 9h-12h em Bogota', st == 200
ok 'Beto nao muda a jornada da Ana: 401', api.(beto, :put, "availabilities/#{ana.id}", { time_zone: 'UTC', windows: [] }).first == 401
ok 'Beto muda a propria', api.(beto, :put, "availabilities/#{beto.id}", { time_zone: 'America/Sao_Paulo', windows: [] }).first == 200

ok 'agente nao cria tipo: 401', api.(beto, :post, 'event_types', { name: 'X' }).first == 401
ok 'duracao invalida: 422', api.(ana, :post, 'event_types', { name: 'X', duration_minutes: 0 }).first == 422
_, consulta = api.(ana, :post, 'event_types', { name: 'Consulta', duration_minutes: 60, buffer_after_minutes: 15, default_owner_id: ana.id })
ok 'tipo criado', consulta['id'].present? && consulta['default_owner_id'] == ana.id

zona = ActiveSupport::TimeZone['America/Bogota']
segunda = (zona.today + 7).beginning_of_week # uma segunda daqui a 1-2 semanas
h = ->(hora) { zona.parse("#{segunda} #{hora}") }
_, livre = api.(beto, :get, "free_slots?event_type_id=#{consulta['id']}&date=#{segunda}")
ok 'dia livre: 9h, 10h e 11h no fuso da Ana (dona padrao do tipo)', livre['owner_id'] == ana.id && livre['slots'] == [h.('09:00'), h.('10:00'), h.('11:00')].map(&:to_i)

Agenda::Appointment.create!(account: account, owner: ana, title: 'Ja marcado', starts_at: h.('10:00'), ends_at: h.('10:30'))
Agenda::Appointment.create!(account: account, owner: ana, title: 'Cancelado', starts_at: h.('11:00'), ends_at: h.('12:00'), status: :cancelled)
_, ocupado = api.(ana, :get, "free_slots?event_type_id=#{consulta['id']}&date=#{segunda}")
ok 'compromisso das 10h tira 10h e, pela folga de 15 min, 9h; cancelado nao ocupa', ocupado['slots'] == [h.('11:00').to_i]

conexao = Agenda::GoogleConnection.create!(account: account, user: ana, email: 'ana@gmail.test', access_token: 'a', refresh_token: 'r', token_expires_at: 1.hour.from_now)
BUSY[conexao.id] = [{ starts_at: h.('11:30'), ends_at: h.('11:45'), all_day: false }]
_, google = api.(ana, :get, "free_slots?event_type_id=#{consulta['id']}&date=#{segunda}")
ok 'ocupado no Google tira as 11h', google['slots'].empty? && google['google_unavailable'] == false
BUSY[conexao.id] = :error
_, fora = api.(ana, :get, "free_slots?event_type_id=#{consulta['id']}&date=#{segunda}")
ok 'Google fora do ar: responde sem ele e avisa', fora['slots'] == [h.('11:00').to_i] && fora['google_unavailable'] == true

tipo = Agenda::EventType.find(consulta['id'])
tipo.update!(booking_window_days: 1)
ok 'alem da janela do tipo: nada', Agenda::FreeSlots.new(event_type: tipo, owner: ana, from: h.('00:00'), to: h.('23:59')).call.slots.empty?
tipo.update!(booking_window_days: 60, minimum_notice_minutes: 30 * 24 * 60)
ok 'antes da antecedencia minima: nada', Agenda::FreeSlots.new(event_type: tipo, owner: ana, from: h.('00:00'), to: h.('23:59')).call.slots.empty?
tipo.update!(minimum_notice_minutes: 120)
ok 'sem jornada (Beto): nada', api.(ana, :get, "free_slots?event_type_id=#{consulta['id']}&owner_id=#{beto.id}&date=#{segunda}")[1]['slots'].empty?
ok 'sabado: nada', api.(ana, :get, "free_slots?event_type_id=#{consulta['id']}&date=#{segunda + 5}")[1]['slots'].empty?
ok 'data invalida: 400', api.(ana, :get, "free_slots?event_type_id=#{consulta['id']}&date=amanha").first == 400

_, confirma = api.(ana, :post, 'event_types', { name: 'Visita', duration_minutes: 30, requires_confirmation: true })
_, visita = api.(ana, :post, 'appointments', { title: 'Visita', event_type_id: confirma['id'], starts_at: h.('09:00').iso8601, ends_at: h.('09:30').iso8601 })
ok 'tipo que pede confirmacao: compromisso nasce pendente', visita['status'] == 'pending' && visita['event_type_id'] == confirma['id']
_, direto = api.(ana, :post, 'appointments', { title: 'Consulta', event_type_id: consulta['id'], starts_at: h.('11:00').iso8601, ends_at: h.('12:00').iso8601 })
ok 'tipo sem confirmacao: confirmado', direto['status'] == 'confirmed'

api.(ana, :delete, "event_types/#{consulta['id']}")
ok 'apagar o tipo mantem os compromissos', Agenda::Appointment.find(direto['id']).event_type_id.nil?
