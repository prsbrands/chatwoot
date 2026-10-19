# Campanhas por QR (Outreach::*, /outreach): telefone, lista (CSV), mensagem
# (variações, opções, bolhas), vetos, preparação, ritmo, envio um por vez, pausa
# por falhas e sessão, atribuição de resposta, API e permissões, contra
# Postgres/Redis descartáveis. O OpenWA entra falso, em memória, e o botlayer
# sem configuração (o número vale a idade da inbox).
require 'active_support/testing/time_helpers'
include ActiveSupport::Testing::TimeHelpers

# A imagem de desenvolvimento (dev-smoke) não traz o roo: o rubyzip só existe no build completo.
module Zip; class Error < StandardError; end; end unless defined?(Zip)

def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

SENT = []
SESSIONS = { 'sess-1' => true }
Integrations::Botlayer::Client.define_singleton_method(:configured?) { false }
Integrations::Openwa::Client.class_eval do
  def initialize(*); end

  def session_for_inbox(_account_id, _inbox_id) = SESSIONS.key?('sess-1') ? 'sess-1' : nil

  def send_text(session, chat_id, text)
    raise Integrations::Openwa::Client::ApiError, 'gateway down' if SESSIONS['fail']

    SENT << { session: session, chat_id: chat_id, text: text }
    { 'id' => SecureRandom.hex(4) }
  end
end
Outreach::Dispatcher.class_eval { def pause_between(_bubble) = nil }

# Telefone
ok 'telefone: local ganha o código do país', Outreach::Phone.normalize('6123-4567') == '+50761234567'
ok 'telefone: com + vale como veio', Outreach::Phone.normalize('+55 (11) 91234-5678') == '+5511912345678'
ok 'telefone: 00 vira +', Outreach::Phone.normalize('0050761234567') == '+50761234567'
ok 'telefone: comprido sem código do país é inválido', Outreach::Phone.normalize('11912345678').nil?
ok 'telefone: já com o código do país', Outreach::Phone.normalize('50761234567') == '+50761234567'
ok 'telefone: lixo é inválido', Outreach::Phone.normalize('abc').nil? && Outreach::Phone.normalize('').nil?

account = Account.create!(name: 'Campanhas', locale: 'es')
account.enable_features!('outreach')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@out.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
agente = User.create!(name: 'Beto Agente', email: "beto-#{SecureRandom.hex(3)}@out.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: agente, role: :agent)
inbox = account.inboxes.create!(name: 'WhatsApp QR', timezone: 'America/Panama',
                                channel: Channel::Api.create!(account: account, webhook_url: 'https://openwa.test/api/ingress/chatwoot-adapter/x/chatwoot'))
site = account.inboxes.create!(name: 'Outra', timezone: 'America/Panama', channel: Channel::Api.create!(account: account, webhook_url: 'https://x.test/hook'))

nova = lambda do |nome, **extra|
  account.outreach_campaigns.create!({ name: nome, inbox: inbox, variants: ['Hola {name}, te escribimos de PRS.'] }.merge(extra))
end
c = nova.('Prueba')
ok 'campanha nasce em rascunho', c.draft? && c.pace.window_start == 8 && c.pace.interval_min == 20
ok 'inbox fora do QR é recusada', Outreach::Campaign.new(account: account, name: 'x', inbox: site, variants: ['a']).invalid?
ok 'até 3 variações', Outreach::Campaign.new(account: account, name: 'x', inbox: inbox, variants: %w[a b c d]).invalid?
ok 'ritmo: intervalo abaixo de 15 s é recusado', Outreach::Campaign.new(account: account, name: 'x', inbox: inbox, variants: ['a'], pacing: { interval_min: 10 }).invalid?
ok 'ritmo: tipo errado é recusado, sem estourar', Outreach::Campaign.new(account: account, name: 'x', inbox: inbox, variants: ['a'], pacing: { max_per_hour: 'muitos' }).invalid?
ok 'ritmo: janela invertida é recusada', Outreach::Campaign.new(account: account, name: 'x', inbox: inbox, variants: ['a'], pacing: { window_start: 20, window_end: 8 }).invalid?
ok 'transição inválida é recusada', (begin; c.transition_to!(:running); false; rescue ActiveRecord::RecordInvalid; true; end)

# Lista (CSV)
csv = Tempfile.new(['lista', '.csv'])
csv.write("﻿Teléfono;Nombre;Empresa;Ciudad\n6123-4567;Luis Gómez;Cortinas SA;David\n+507 6999-0000;Marta Ríos;;Colón\n6123-4567;Luis Duplicado;;David\n123;Sin Numero;;\n\n")
csv.flush
file = Struct.new(:path, :original_filename).new(csv.path, 'lista.csv')
sheet = Outreach::Sheet.read(file)
ok 'planilha: títulos e linhas, ";" detectado, BOM fora', sheet.headers == %w[Teléfono Nombre Empresa Ciudad] && sheet.rows.size == 4
ok 'planilha: tipo não suportado', (begin; Outreach::Sheet.read(Struct.new(:path, :original_filename).new(csv.path, 'lista.xls')); false; rescue Outreach::Sheet::Invalid; true; end)
n = Outreach::Importer.new(c, sheet, { 'phone' => 'Teléfono', 'name' => 'Nombre', 'company' => 'Empresa' }).perform
luis, marta, dup, sem = c.recipients.order(:id).to_a
ok 'importa: telefone em E.164 e nome', n == 4 && luis.phone == '+50761234567' && luis.name == 'Luis Gómez' && marta.phone == '+50769990000'
ok 'importa: colunas viram variáveis sem acento', luis.variables == { 'telefono' => '6123-4567', 'nombre' => 'Luis Gómez', 'empresa' => 'Cortinas SA', 'ciudad' => 'David', 'company' => 'Cortinas SA' } &&
                                                 marta.variables['ciudad'] == 'Colón'
ok 'importa: telefone inválido fica como veio', sem.phone == '123'

# Mensagem
def pessoa(campaign, name, vars = {}, variant: 0) = Outreach::Recipient.new(name: name, variables: vars, variant: variant)
c.update!(variants: ['Hola {name}!', '{Hola|Buenas} {name}, en {ciudad}.'], opt_out_footer: 'Responde PARAR para no recibir más.')
ok 'mensagem: primeiro nome', Outreach::Message.new(c, pessoa(c, 'Luis Gómez')).bubbles.first == 'Hola Luis!'
ok 'mensagem: opção sorteada e variável da coluna', %w[Hola Buenas].include?(Outreach::Message.new(c, pessoa(c, 'Luis', { 'ciudad' => 'David' }, variant: 1)).bubbles.first.split.first) &&
                                                    Outreach::Message.new(c, pessoa(c, 'Luis', { 'ciudad' => 'David' }, variant: 1)).bubbles.first.end_with?('en David.')
ok 'mensagem: rodapé de saída como última bolha', Outreach::Message.new(c, pessoa(c, 'Luis')).bubbles.last == 'Responde PARAR para no recibir más.'
ok 'mensagem: variável que falta (qualquer variação)', Outreach::Message.new(c, pessoa(c, 'Luis', variant: nil)).missing == ['ciudad'] &&
                                                       Outreach::Message.new(c, pessoa(c, nil, variant: nil)).missing.include?('name')
longo = nova.('Largo', variants: ["Uno\n\nDos\n\nTres\n\nCuatro\n\nCinco\n\nSeis"])
ok 'mensagem: no máximo 4 bolhas, o resto vai junto na última', Outreach::Message.new(longo, pessoa(longo, 'x')).bubbles == ['Uno', 'Dos', 'Tres', "Cuatro\n\nCinco\n\nSeis"]
c.update!(opt_out_footer: nil, variants: ['Hola {name}, te escribimos de PRS.'])

# Vetos
account.contacts.create!(name: 'Bloqueado', phone_number: '+50769990000', blocked: true)
account.outreach_suppressions.create!(phone: '+50761234567', reason: 'contador')
ok 'veto: bloqueado é opt_out', Outreach::Eligibility.new(c, [marta]).reason(marta) == 'opt_out'
ok 'veto: lista de exclusão', Outreach::Eligibility.new(c, [luis]).reason(luis) == 'suppressed'
ok 'veto: sem telefone / inválido', Outreach::Eligibility.new(c, [sem]).reason(sem) == 'invalid_phone' &&
                                    Outreach::Eligibility.new(c, [Outreach::Recipient.new(phone: '')]).reason(Outreach::Recipient.new(phone: '')) == 'no_phone'
account.outreach_suppressions.delete_all
account.contacts.where(phone_number: '+50769990000').update_all(blocked: false)
ok 'veto: telefone repetido, vale o primeiro', (e = Outreach::Eligibility.new(c, [luis, dup])) && e.reason(luis).nil? && e.reason(dup) == 'duplicate'
quente = account.contacts.create!(name: 'Atendido', phone_number: '+50760000001')
ci = ContactInbox.create!(contact: quente, inbox: inbox, source_id: SecureRandom.uuid)
Conversation.create!(account: account, inbox: inbox, contact: quente, contact_inbox: ci, status: :open, assignee: agente)
pq = Outreach::Recipient.new(phone: '+50760000001', name: 'Atendido')
ok 'veto: conversa aberta com a equipe', Outreach::Eligibility.new(c, [pq]).reason(pq) == 'active_conversation'

# Preparação
account.outreach_suppressions.create!(phone: '+50761234567')
marta.update!(excluded_reason: nil)
contagem = Outreach::Prepare.new(c).perform
ok 'preparar: contagem por motivo e campanha pronta', c.reload.ready? && contagem == { 'suppressed' => 2, nil => 1, 'invalid_phone' => 1 }
ok 'preparar: quem pode receber fica pending, os outros excluded com o motivo', c.recipients.pending.pluck(:phone) == ['+50769990000'] &&
                                                                                c.recipients.excluded.pluck(:excluded_reason).sort == %w[invalid_phone suppressed suppressed]
dup.update!(status: :excluded, excluded_reason: 'manual')
Outreach::Prepare.new(c).perform
ok 'preparar de novo: a exclusão à mão continua', dup.reload.excluded_reason == 'manual' && c.reload.ready?

# Ritmo (terça 20/10/2026, 10h no Panamá)
dentro = Time.find_zone('America/Panama').local(2026, 10, 20, 10, 0)
travel_to(dentro) do
  c.update!(pacing: c.pacing)
  ok 'ritmo: dentro da janela, nada a esperar', Outreach::Pace.new(c).wait.nil?
end
travel_to(Time.find_zone('America/Panama').local(2026, 10, 20, 21, 0)) do
  w = Outreach::Pace.new(c).wait
  ok 'ritmo: fora da janela espera a abertura do dia seguinte', w.reason == :outside_window && w.until == Time.find_zone('America/Panama').local(2026, 10, 21, 8, 0)
end
travel_to(Time.find_zone('America/Panama').local(2026, 10, 24, 21, 0)) do
  w = Outreach::Pace.new(c).wait
  ok 'ritmo: sábado à noite vai para segunda (domingo fora dos dias)', w.until == Time.find_zone('America/Panama').local(2026, 10, 26, 8, 0)
end
travel_to(dentro) do
  c.update!(next_send_at: dentro + 30.seconds)
  ok 'ritmo: intervalo ainda não passou', Outreach::Pace.new(c).wait.reason == :interval
  c.update!(next_send_at: nil)
  limite = nova.('Limite', pacing: { max_per_day: 1 })
  limite.recipients.create!(account: account, phone: '+50760000009', status: :sent, sent_at: dentro - 2.hours)
  ok 'ritmo: teto diário da campanha', Outreach::Pace.new(limite).wait&.reason == :daily_cap
  hora = nova.('Hora', pacing: { max_per_hour: 1 })
  hora.recipients.create!(account: account, phone: '+50760000008', status: :sent, sent_at: dentro - 10.minutes)
  ok 'ritmo: teto por hora', Outreach::Pace.new(hora).wait&.reason == :hourly_cap
  ok 'número novo: teto de 20 por dia (idade da inbox)', Outreach::NumberBudget.new(inbox).daily_cap(dentro) == 20
  ok 'número de 20 dias: teto de 200', Outreach::NumberBudget.new(inbox).daily_cap(dentro + 20.days) == 200
  fria = nova.('Fria', cold: true)
  ok 'lista fria: metade do teto do dia', Outreach::NumberBudget.new(inbox).allowance(dentro, cold: true) == 10
end

# Envio
SENT.clear
c.update!(variants: ['Hola {name}!', "Buenas {name}.\n\nSomos PRS."], pacing: { batch_size: 2, batch_pause_min: 5, batch_pause_max: 5, interval_min: 20, interval_max: 20 })
c.recipients.where(excluded_reason: %w[suppressed manual]).update_all(status: Outreach::Recipient.statuses[:cancelled], excluded_reason: nil)
extra = [['+50761111111', 'Ana Uno'], ['+50762222222', 'Beto Dos'], ['+50763333333', 'Cris Tres']].map do |phone, name|
  c.recipients.create!(account: account, phone: phone, name: name)
end
travel_to(dentro) do
  c.reload.start!
  ok 'iniciar: campanha rodando e cadeia acordada', c.running? && c.wake_at.present? && c.started_at.present?
  proxima = Outreach::Dispatcher.new(c).run
  ok 'envio: uma pessoa, pelo gateway, com chat id do WhatsApp', SENT.size == 1 && SENT.first[:chat_id] == '+50769990000'.delete('+') + '@c.us' && SENT.first[:text] == 'Hola Marta!' &&
                                                                   c.recipients.sent.count == 1
  ok 'envio: próximo no intervalo aleatório (20 s)', proxima == dentro + 20.seconds && c.reload.next_send_at == proxima && c.batch_sent == 1
  ok 'envio: dentro do intervalo espera', Outreach::Dispatcher.new(c).run == proxima && SENT.size == 1
end
travel_to(dentro + 21.seconds) do
  proxima = Outreach::Dispatcher.new(c.reload).run
  ok 'envio: segunda pessoa com a outra variação em duas bolhas', SENT.size == 3 && SENT[1][:text].start_with?('Buenas') && SENT[2][:text] == 'Somos PRS.'
  ok 'envio: fim do lote, descanso de 5 min e contador zerado', proxima == dentro + 21.seconds + 5.minutes && c.reload.batch_sent == 0
end
ok 'job de uma volta: acordar velho não faz nada', (Outreach::SendNextJob.perform_now(c.reload, 1.0); SENT.size == 3)

# Veto na hora do envio
travel_to(dentro + 10.minutes) do
  alvo = c.recipients.pending.order(:id).first
  account.contacts.create!(name: alvo.name, phone_number: alvo.phone, blocked: true)
  c.update!(next_send_at: nil)
  Outreach::Dispatcher.new(c.reload).run
  ok 'veto na hora: quem pediu para parar sai da fila e não recebe', alvo.reload.excluded? && alvo.excluded_reason == 'opt_out' && SENT.none? { |m| m[:chat_id] == alvo.phone.delete('+') + '@c.us' }
  ok 'o próximo da fila recebeu no lugar', SENT.size == 4
end

# Falhas pausam
travel_to(dentro + 30.minutes) do
  SESSIONS['fail'] = true
  c.update!(next_send_at: nil)
  [['+50764444444', 'Dani'], ['+50764444445', 'Eli'], ['+50764444446', 'Fer']].each { |phone, name| c.recipients.create!(account: account, phone: phone, name: name) }
  3.times do
    c.update!(next_send_at: nil)
    Outreach::Dispatcher.new(c.reload).run
  end
  ok 'falhas seguidas pausam a campanha, sem reenviar', c.reload.paused? && c.paused_reason == 'send_failures' && c.recipients.failed.count == 3 && c.recipients.failed.all? { |r| r.error.include?('gateway down') }
  SESSIONS.delete('fail')
end

# Sessão sumida
sem_sessao = nova.('Sem sessao')
sem_sessao.recipients.create!(account: account, phone: '+50765555555', name: 'Eva')
sem_sessao.transition_to!(:ready)
travel_to(dentro + 40.minutes) do
  sem_sessao.start!
  SESSIONS.delete('sess-1')
  Outreach::Dispatcher.new(sem_sessao.reload).run
  ok 'sem sessão no gateway: pausa e a pessoa falha sem mandar', sem_sessao.reload.paused? && sem_sessao.paused_reason == 'session_not_found' && sem_sessao.recipients.failed.count == 1
  SESSIONS['sess-1'] = true
end
ok 'iniciar sem ninguém para receber: 422', (begin; vazia = nova.('Vazia'); vazia.transition_to!(:ready); vazia.start!; false; rescue ActiveRecord::RecordInvalid; true; end)
utc = account.inboxes.create!(name: 'UTC', channel: Channel::Api.create!(account: account, webhook_url: 'https://openwa.test/api/ingress/chatwoot-adapter/y/chatwoot'))
ok 'iniciar com inbox em UTC: 422', (begin; u = account.outreach_campaigns.create!(name: 'U', inbox: utc, variants: ['a']); u.recipients.create!(account: account, phone: '+50766666666'); u.transition_to!(:ready); u.start!; false; rescue ActiveRecord::RecordInvalid; true; end)

# Conclusão
fim = nova.('Fim')
fim.recipients.create!(account: account, phone: '+50767777777', name: 'Gus')
fim.transition_to!(:ready)
travel_to(dentro + 1.hour) do
  fim.start!
  Outreach::Dispatcher.new(fim.reload).run
end
travel_to(dentro + 1.hour + 2.minutes) do
  ok 'campanha conclui quando a lista acaba', Outreach::Dispatcher.new(fim.reload).run.nil? && fim.reload.completed? && fim.completed_at.present?
end

# Vigia
morta = nova.('Morta')
morta.recipients.create!(account: account, phone: '+50768888888')
morta.transition_to!(:ready)
travel_to(dentro + 2.hours) do
  morta.start!
  morta.update_columns(wake_at: dentro + 2.hours - 10.minutes)
  morta.recipients.update_all(status: Outreach::Recipient.statuses[:sending], updated_at: dentro + 2.hours - 20.minutes)
  Outreach::WatchdogJob.perform_now
  ok 'vigia: envio parado vira falha e não é repetido', morta.recipients.first.failed? && morta.recipients.first.error.include?('not retried')
  ok 'vigia: cadeia morta é religada', morta.reload.wake_at >= dentro + 2.hours - 1.second
  3.times { inbox.channel.authorization_error! }
  morta.update_columns(wake_at: dentro + 2.hours)
  Outreach::WatchdogJob.perform_now
  ok 'vigia: sessão caída pausa a campanha', morta.reload.paused? && morta.paused_reason == 'session_down'
  inbox.channel.reauthorized!
end

# Resposta do cliente
rc = nova.('Resposta', attribution_hours: 72)
agora = Time.current
rc.recipients.create!(account: account, phone: '+50769000001', name: 'Rita', status: :sent, sent_at: agora - 1.day)
rc.recipients.create!(account: account, phone: '+50769000002', name: 'Saul', status: :sent, sent_at: agora - 5.days)
rc.recipients.create!(account: account, phone: '+50769000003', name: 'Tito', status: :sent, sent_at: agora - 1.day)
resposta = lambda do |telefone, bloqueado: false, identificador: nil|
  contato = account.contacts.create!(name: "Contato #{telefone}", phone_number: identificador ? nil : telefone, identifier: identificador, blocked: bloqueado)
  ci2 = ContactInbox.create!(contact: contato, inbox: inbox, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: inbox, contact: contato, contact_inbox: ci2)
  conv.messages.create!(account: account, inbox: inbox, message_type: :incoming, content: 'hola', sender: contato)
end
rita_msg = resposta.('+50769000001')
Outreach::Reply.new(rita_msg).perform
rita = rc.recipients.find_by(phone: '+50769000001')
ok 'resposta: a campanha ganha contato, conversa e carimbo', rita.replied? && rita.contact_id == rita_msg.conversation.contact_id && rita.conversation_id == rita_msg.conversation_id
Outreach::Reply.new(resposta.('+50769000002')).perform
ok 'resposta fora da janela de atribuição não conta', rc.recipients.find_by(phone: '+50769000002').sent?
Outreach::Reply.new(resposta.('+50769000003', bloqueado: true)).perform
ok 'resposta de quem pediu para parar vira opted_out', rc.recipients.find_by(phone: '+50769000003').opted_out?
rc.recipients.create!(account: account, phone: '+50769000004', name: 'Uma', status: :sent, sent_at: agora - 1.hour)
Outreach::Reply.new(resposta.(nil, identificador: '50769000004@c.us')).perform
ok 'resposta de contato só com o JID do WhatsApp', rc.recipients.find_by(phone: '+50769000004').replied?
m = Outreach::Metrics.new(rc).perform
ok 'métricas: enviadas, respostas, parar, taxa', m[:sent] == 4 && m[:replied] == 3 && m[:opted_out] == 1 && m[:reply_rate] == 0.75

# API e permissões
s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil, multipart: false|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/outreach/#{path}",
                params: multipart ? body : body&.to_json,
                headers: { 'api_access_token' => user.access_token.token }.merge(multipart ? {} : { 'Content-Type' => 'application/json' }))
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end
st, = api.(agente, :get, 'campaigns')
ok 'agente não vê campanhas (401)', st == 401
st, nova_c = api.(admin, :post, 'campaigns', { name: 'Por API', inbox_id: inbox.id, variants: ['Hola {name}'], cold: true, opt_out_footer: 'PARAR para salir',
                                              pacing: { interval_min: 25, interval_max: 40, days: [1, 2, 3] } })
ok 'criar campanha pela API', st == 200 && nova_c['status'] == 'draft' && nova_c['cold'] && nova_c['pacing']['interval_min'] == 25 && nova_c['pacing']['days'] == [1, 2, 3]
st, = api.(admin, :post, 'campaigns', { name: 'Ruim', inbox_id: inbox.id, variants: [], pacing: {} })
ok 'criar sem texto: 422', st == 422
st, = api.(admin, :post, 'campaigns', { name: 'Ruim', inbox_id: inbox.id, variants: ['a'], pacing: { interval_min: 5 } })
ok 'criar com ritmo abaixo do piso: 422', st == 422
st, prev = api.(admin, :post, 'campaigns/preview_import', { file: Rack::Test::UploadedFile.new(csv.path, 'text/csv', original_filename: 'lista.csv') }, multipart: true)
ok 'prévia da importação: colunas, amostra e palpite do mapeamento', st == 200 && prev['headers'].size == 4 && prev['total'] == 4 && prev['mapping'] == { 'phone' => 'Teléfono', 'name' => 'Nombre', 'company' => 'Empresa' }
id = nova_c['id']
st, = api.(admin, :post, "campaigns/#{id}/audience",
           { source: 'import', mapping: { phone: 'Teléfono', name: 'Nombre' }, file: Rack::Test::UploadedFile.new(csv.path, 'text/csv', original_filename: 'lista.csv') }, multipart: true)
ok 'importar a lista pela API', st == 200 && account.outreach_recipients.where(campaign_id: id).count == 4
st, = api.(admin, :post, "campaigns/#{id}/audience",
           { source: 'import', mapping: { phone: 'Nada' }, file: Rack::Test::UploadedFile.new(csv.path, 'text/csv', original_filename: 'lista.csv') }, multipart: true)
ok 'importar sem a coluna de telefone mapeada: 422', st == 422
st, prep = api.(admin, :post, "campaigns/#{id}/prepare")
ok 'preparar pela API: a campanha volta pronta, com as contagens', st == 200 && prep['status'] == 'ready' && prep['metrics']['total'] == 4 &&
                                                                     prep['metrics']['pending'] + prep['metrics']['excluded'] == 4
st, reds = api.(admin, :get, "campaigns/#{id}/recipients?status=excluded")
ok 'lista de excluídos com o motivo', st == 200 && reds['payload'].all? { |r| r['excluded_reason'].present? } && reds['meta']['count'] == reds['payload'].size
st, upd = api.(admin, :put, "campaigns/#{id}", { name: 'Por API 2' })
ok 'editar uma campanha pronta volta a rascunho', st == 200 && upd['status'] == 'draft' && upd['name'] == 'Por API 2'
api.(admin, :post, "campaigns/#{id}/prepare")
st, = api.(admin, :post, "campaigns/#{id}/test", { phone: 'abc' })
ok 'teste com telefone inválido: 422', st == 422
SENT.clear
st, tst = api.(admin, :post, "campaigns/#{id}/test", { phone: '6000-0000' })
ok 'enviar teste para mim, fora da lista', st == 200 && SENT.size == 2 && SENT.first[:chat_id] == '50760000000@c.us' && tst['bubbles'].last == 'PARAR para salir' &&
                                           account.outreach_recipients.where(campaign_id: id).where.not(sent_at: nil).none?
st, c2 = api.(admin, :post, "campaigns/#{id}/cancel")
ok 'cancelar: pessoas pendentes canceladas', st == 200 && c2['status'] == 'cancelled' && account.outreach_recipients.where(campaign_id: id).pending.none?
st, = api.(admin, :delete, "campaigns/#{id}")
ok 'apagar campanha cancelada', st == 200 && !account.outreach_campaigns.exists?(id)
st, = api.(admin, :delete, "campaigns/#{c.id}")
ok 'apagar campanha pausada: 422', st == 422 && account.outreach_campaigns.exists?(c.id)
_, aten = api.(admin, :get, 'campaigns/attention_count')
ok 'número do menu: pausadas pelo sistema', aten['count'] == account.outreach_campaigns.paused.where.not(paused_reason: 'manual').count && aten['count'] >= 2

# Exclusões
st, sup = api.(admin, :post, 'suppressions', { phones: "6111-2222\n+507 6333-4444, abc; 6111-2222" })
ok 'exclusões: vários números, repetido e inválido', st == 200 && sup['added'] == 2 && sup['invalid'] == ['abc']
_, sl = api.(admin, :get, 'suppressions')
ok 'exclusões: lista', (%w[+50761112222 +50763334444] - sl['payload'].map { |p| p['phone'] }).empty?
st, = api.(agente, :get, 'suppressions')
ok 'agente não vê exclusões (401)', st == 401
st, = api.(admin, :delete, "suppressions/#{sl['payload'].first['id']}")
ok 'remover exclusão', st == 200

# Flag
account.disable_features!('outreach')
st, = api.(admin, :get, 'campaigns')
ok 'sem a flag: 401', st == 401
