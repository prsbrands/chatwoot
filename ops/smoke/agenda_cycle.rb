# Agenda, fechando o ciclo: Google Meet no evento, negocio que anda ao marcar,
# mensagem de falta e a presenca cobrada no Radar, contra Postgres/Redis
# descartaveis. O Google e falso: devolve um hangoutLink e guarda os corpos.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

BODIES = []
Agenda::GoogleCalendar.class_eval do
  def upsert_event(appointment)
    BODIES << send(:event_body, appointment)
    { 'id' => appointment.google_event_key, 'hangoutLink' => (appointment.event_type&.google_meet ? 'https://meet.google.com/abc-defg-hij' : nil) }
  end
end

account = Account.create!(name: 'Ciclo', locale: 'es')
account.enable_features!('sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@ciclo.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
conexao = Agenda::GoogleConnection.create!(account: account, user: ana, email: 'ana@gmail.test', access_token: 'a', refresh_token: 'r',
                                           token_expires_at: 1.hour.from_now)
qr = account.inboxes.create!(name: 'WA QR', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/plugins/chatwoot-adapter/x'))
contact = account.contacts.create!(name: 'Maria Lopez')
ci = ContactInbox.create!(contact: contact, inbox: qr, source_id: SecureRandom.uuid)
conversation = Conversation.create!(account: account, inbox: qr, contact: contact, contact_inbox: ci)
deal = Sales::Deal.open_for_contact!(contact, conversation: conversation)
pipeline = deal.pipeline
etapas = pipeline.stages.open.order(:position).to_a
reuniao = etapas[2]

tipo = Agenda::EventType.create!(account: account, name: 'Consulta', default_owner: ana, google_meet: true, booked_stage: reuniao,
                                 reminder_minutes_before: 1440, reminder_message: 'Hola {name}, tu {type} es a las {time}: {link}',
                                 no_show_message: 'Hola {name}, te extranamos hoy. Quieres otro horario?')
inicio = 3.hours.from_now.change(min: 0)
marcado = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo, deal: deal, conversation: conversation,
                                      title: 'Consulta — Maria', starts_at: inicio, ends_at: inicio + 1.hour)

ok 'ao marcar, o negocio vai para a etapa do tipo, movido pela IA', deal.reload.stage == reuniao &&
                                                                  deal.transitions.first.actor_type == 'ai' &&
                                                                  deal.transitions.first.reason == 'Consulta booked'

Agenda::GooglePushJob.perform_now(marcado.id, nil)
ok 'primeiro envio pede a sala do Meet', BODIES.last.dig(:conferenceData, :createRequest, :conferenceSolutionKey, :type) == 'hangoutsMeet' &&
                                        BODIES.last.dig(:conferenceData, :createRequest, :requestId) == "cgchat#{marcado.id}"
ok 'o link do Meet fica no compromisso', marcado.reload.meeting_url == 'https://meet.google.com/abc-defg-hij'
Agenda::GooglePushJob.perform_now(marcado.id, conexao.id)
ok 'com o link gravado, nao pede outra sala', !BODIES.last.key?(:conferenceData) && marcado.reload.meeting_url.present?

Agenda::ReminderJob.perform_now
local = inicio.in_time_zone(Time.zone)
ok 'lembrete com {link} trocado pelo Meet', conversation.messages.outgoing.exists?(content: "Hola Maria, tu Consulta es a las #{local.strftime('%H:%M')}: https://meet.google.com/abc-defg-hij")

atras = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo, deal: deal, title: 'Antes',
                                    starts_at: inicio + 1.day, ends_at: inicio + 1.day + 1.hour, created_by: ana)
deal.reload
ok 'marcar de novo nao volta o negocio (so anda para a frente)', deal.stage == reuniao && atras.persisted?
outro = Sales::Pipeline.create_with_template!(account, name: 'Outro funil')
tipo.update!(booked_stage: outro.stages.open.order(:position).last)
Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo, deal: deal, title: 'Outro funil',
                            starts_at: inicio + 2.days, ends_at: inicio + 2.days + 1.hour)
ok 'etapa de outro funil nao move', deal.reload.stage == reuniao

passado = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo, contact: contact, conversation: conversation,
                                      title: 'Passado', starts_at: 3.hours.ago, ends_at: 2.hours.ago)
feito = Agenda::Appointment.create!(account: account, owner: ana, title: 'Feito', contact: contact,
                                    starts_at: 5.hours.ago, ends_at: 4.hours.ago, status: :completed)
pendentes = Sales::Radar.new(account).awaiting_outcome.map(&:id)
ok 'Radar cobra a presenca do que ja passou sem desfecho', pendentes.include?(passado.id) && !pendentes.include?(feito.id) &&
                                                         !pendentes.include?(marcado.id)

antes = conversation.messages.outgoing.count
passado.update!(status: :no_show)
ok 'nao compareceu: mensagem de falta ao cliente', conversation.messages.outgoing.count == antes + 1 &&
                                                  conversation.messages.outgoing.last.content == 'Hola Maria, te extranamos hoy. Quieres otro horario?'
ok 'e sai do Radar', Sales::Radar.new(account).awaiting_outcome.map(&:id).exclude?(passado.id)
tipo.update!(no_show_message: nil)
sem_texto = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo, contact: contact, conversation: conversation,
                                        title: 'Sem texto', starts_at: 6.hours.ago, ends_at: 5.hours.ago)
antes = conversation.messages.outgoing.count
sem_texto.update!(status: :no_show)
ok 'tipo sem mensagem de falta: nada sai', conversation.messages.outgoing.count == antes
