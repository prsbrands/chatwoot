# Agenda, 3a parte: a IA marcando (/agenda/bot/slots e /bot/bookings) e os
# lembretes pelo WhatsApp por QR (Agenda::ReminderJob), contra Postgres/Redis
# descartaveis. O Google fica de fora (ninguem conectado).
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'IA marca', locale: 'es')
account.enable_features!('sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@ia.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
Agenda::Availability.create!(account: account, user: ana, time_zone: 'America/Bogota',
                             windows: (0..6).map { |day| { 'day' => day, 'start' => '08:00', 'end' => '20:00' } })

qr = account.inboxes.create!(name: 'WA QR', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/plugins/chatwoot-adapter/x'))
site = account.inboxes.create!(name: 'Site', channel: Channel::Api.create!(account: account))
def conversa(account, inbox, nome)
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
end
c1 = conversa(account, qr, 'Maria Lopez')
deal = Sales::Deal.open_for_contact!(c1.contact, conversation: c1)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/agenda/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => ana.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

ok 'sem tipo da IA: available false', api.(:get, 'bot/slots')[1] == { 'available' => false }
ok 'IA marca sem responsavel padrao: 422', api.(:post, 'event_types', { name: 'X', ai_bookable: true }).first == 422
ok 'lembrete sem texto: 422', api.(:post, 'event_types', { name: 'X', reminder_minutes_before: 60 }).first == 422
_, tipo = api.(:post, 'event_types', { name: 'Consulta', duration_minutes: 60, ai_bookable: true, default_owner_id: ana.id,
                                       reminder_minutes_before: 1440, reminder_message: 'Hola {name}! Tu {type} es el {date} a las {time}.' })
_, slots = api.(:get, 'bot/slots')
ok 'horarios da IA: no fuso da Ana, com offset', slots['available'] && slots['event_type']['name'] == 'Consulta' &&
                                               slots['time_zone'] == 'America/Bogota' && slots['slots'].first.end_with?('-05:00') &&
                                               slots['slots'].size == Agenda::AiBooking::MAX_SLOTS

escolhido = slots['slots'][2]
st, marcado = api.(:post, 'bot/bookings', { conversation_id: c1.display_id, starts_at: escolhido })
compromisso = Agenda::Appointment.find_by(id: marcado&.dig('id'))
ok 'marcar: compromisso da Ana com o contato, a conversa e o negocio', st == 200 && compromisso.owner == ana && compromisso.contact == c1.contact &&
                                                                      compromisso.conversation == c1 && compromisso.deal == deal &&
                                                                      compromisso.starts_at == Time.zone.iso8601(escolhido) && compromisso.confirmed?
nota = c1.messages.where(private: true).last
Messages::MentionService.new(message: nota).perform if nota # no app roda pelo AsyncDispatcher
ok 'nota privada mencionando a Ana, que recebe a notificacao', nota&.content.to_s.include?("mention://user/#{ana.id}/") &&
                                                                nota.content.include?('Consulta') &&
                                                                Notification.where(user: ana, notification_type: 'conversation_mention').exists?

st, conflito = api.(:post, 'bot/bookings', { conversation_id: c1.display_id, starts_at: escolhido })
ok 'mesmo horario de novo: 409 com 3 alternativas depois dele', st == 409 && conflito['alternatives'].size == 3 &&
                                                                 conflito['time_zone'] == 'America/Bogota' &&
                                                                 conflito['alternatives'].all? { |slot| Time.zone.iso8601(slot) > Time.zone.iso8601(escolhido) }
ok 'horario fora da lista: 409', api.(:post, 'bot/bookings', { conversation_id: c1.display_id, starts_at: 3.minutes.from_now.iso8601 }).first == 409
ok 'starts_at invalido: 400', api.(:post, 'bot/bookings', { conversation_id: c1.display_id, starts_at: 'amanha' }).first == 400

Agenda::EventType.find(tipo['id']).update!(requires_confirmation: true)
_, pendente = api.(:post, 'bot/bookings', { conversation_id: c1.display_id, starts_at: slots['slots'][5] })
ok 'tipo com confirmacao: a IA marca pendente', pendente['status'] == 'pending'

# --- lembretes ---------------------------------------------------------------
tipo_db = Agenda::EventType.find(tipo['id'])
cedo = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo_db, contact: c1.contact, conversation: c1, title: 'Logo',
                                   starts_at: 3.hours.from_now, ends_at: 4.hours.from_now)
longe = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo_db, contact: c1.contact, conversation: c1, title: 'Longe',
                                    starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour)
c2 = conversa(account, site, 'Pedro Site')
fora_do_qr = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo_db, contact: c2.contact, conversation: c2,
                                         title: 'Site', starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
cancelado = Agenda::Appointment.create!(account: account, owner: ana, event_type: tipo_db, contact: c1.contact, conversation: c1,
                                        title: 'Cancelado', starts_at: 2.hours.from_now, ends_at: 3.hours.from_now, status: :cancelled)
antes = c1.messages.outgoing.count
Agenda::ReminderJob.perform_now
local = cedo.starts_at.in_time_zone('America/Bogota')
lembrete = c1.messages.outgoing.find_by(content: "Hola Maria! Tu Consulta es el #{local.strftime('%d/%m')} a las #{local.strftime('%H:%M')}.")
ok 'lembrete no QR, sem remetente, com nome, tipo, dia e hora', cedo.reload.reminder_sent_at.present? && lembrete && lembrete.sender.nil?
ok 'fora da antecedencia: ainda nao', longe.reload.reminder_sent_at.nil?
ok 'conversa fora do QR: nao manda', fora_do_qr.reload.reminder_sent_at.nil? && c2.messages.outgoing.none?
ok 'cancelado: nao manda', cancelado.reload.reminder_sent_at.nil?
ok 'um por compromisso confirmado e dentro do prazo (o marcado pela IA tambem; o pendente nao)', c1.messages.outgoing.count == antes + 2 &&
                                                                                                   compromisso.reload.reminder_sent_at.present?
Agenda::ReminderJob.perform_now
ok 'rodar de novo nao repete', c1.messages.outgoing.count == antes + 2

c1.contact.update!(blocked: true)
longe.update!(starts_at: 2.hours.from_now, ends_at: 3.hours.from_now)
Agenda::ReminderJob.perform_now
ok 'contato bloqueado: nao manda', longe.reload.reminder_sent_at.nil?
