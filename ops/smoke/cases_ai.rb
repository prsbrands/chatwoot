# Casos, fases 2 e 3: o que o n8n usa (cases/bot/*), o repasse da equipe pela
# IA, a resposta do cliente, os avisos ao cliente e as métricas, contra
# Postgres/Redis descartáveis.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Casos IA', locale: 'es')
account.enable_features!('cases')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@casosia.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
agente = User.create!(name: 'Beto Agente', email: "beto-#{SecureRandom.hex(3)}@casosia.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: agente, role: :agent)
canal = Channel::Api.create!(account: account, webhook_url: 'https://openwa.test/hook')
inbox = account.inboxes.create!(name: 'WhatsApp', channel: canal)
sem_webhook = account.inboxes.create!(name: 'Voz', channel: Channel::Api.create!(account: account))

conversa = lambda do |contact, caixa = inbox|
  ci = ContactInbox.create!(contact: contact, inbox: caixa, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: caixa, contact: contact, contact_inbox: ci)
  conv.messages.create!(account: account, inbox: caixa, message_type: :incoming, content: 'Hola', sender: contact)
  conv
end
maria = account.contacts.create!(name: 'María')
conv = conversa.(maria)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

tipos = Cases::Type.for(account).to_a
problema = tipos[1]
problema.update!(ai_mode: :continue, ai_instructions: 'Producto con defecto o pedido equivocado', notify_customer: true)
reclamo = tipos[3]
reclamo.update!(ai_mode: :handoff, default_assignee: agente)

# Contexto
st, = api.(agente, :get, "cases/bot/context?conversation_id=#{conv.display_id}")
ok 'bot: agente não usa (401)', st == 401
st, ctx = api.(admin, :get, "cases/bot/context?conversation_id=#{conv.display_id}")
ok 'contexto: só os tipos com IA, com modo e critério', st == 200 && ctx['types'].map { |t| t['name'] } == %w[Problema Reclamo] &&
                                                      ctx['types'][0]['ai_mode'] == 'continue' && ctx['types'][0]['instructions'].include?('defecto') &&
                                                      ctx['open_cases'] == []

# A IA abre
st, = api.(admin, :post, 'cases/bot/cases', { conversation_id: conv.display_id, type_id: tipos[0].id, title: 'x', description: 'x' })
ok 'tipo sem IA: 404', st == 404
st, aberto = api.(admin, :post, 'cases/bot/cases',
                  { conversation_id: conv.display_id, type_id: problema.id, title: 'Me llegó la cortina rota', description: 'Me llegó la cortina rota, ¿qué hago?', language: 'es' })
kase = Cases::Case.find(aberto['id'])
ok 'IA abre: origem ai, conversa de origem, idioma guardado', st == 200 && !aberto['reused'] && aberto['ai_mode'] == 'continue' && kase.source_ai? &&
                                                            kase.main_conversation == conv && kase.customer_language == 'es' && kase.events.first.by_ai?
nota = conv.messages.where(private: true).last
ok 'sem responsável: menciona o primeiro admin, com o texto da IA', nota && nota.content.include?("mention://user/#{admin.id}/") && nota.content.include?('the AI opened')
ok 'aberto pela IA: sem aviso de abertura ao cliente (a resposta dela já dá o número)',
   conv.messages.outgoing.where(private: false).none? && kase.events.customer_notified.none?
st, de_novo = api.(admin, :post, 'cases/bot/cases', { conversation_id: conv.display_id, type_id: problema.id, title: 'Otra vez', description: 'Sigo esperando' })
ok 'mesmo tipo ativo: vira nota no caso, sem outro', st == 200 && de_novo['reused'] && de_novo['id'] == kase.id && account.cases.count == 1 &&
                                                   kase.events.ai_note.last&.body == 'Sigo esperando'
_, ctx = api.(admin, :get, "cases/bot/context?conversation_id=#{conv.display_id}")
ok 'contexto lista o caso ativo do cliente', ctx['open_cases'].map { |c| c['number'] } == [kase.number] && ctx['open_cases'][0]['awaiting_customer_info'] == false
st, h = api.(admin, :post, 'cases/bot/cases', { conversation_id: conv.display_id, type_id: reclamo.id, title: 'Quiero hablar con alguien', description: 'Pésimo servicio' })
ok 'tipo que passa a conversa: responsável padrão mencionado', st == 200 && h['ai_mode'] == 'handoff' &&
                                                              conv.messages.where(private: true).last.content.include?("mention://user/#{agente.id}/")

# A equipe responde pela IA
st, = api.(agente, :post, "cases/#{kase.id}/relay", { body: 'Mandamos otra el lunes', mode: 'shout' })
ok 'modo inválido: 422', st == 422
st, c = api.(agente, :post, "cases/#{kase.id}/relay", { body: 'Mándanos una foto de la cortina, por favor', mode: 'ask' })
rel = c['events'].last
ok 'repasse pendente no histórico', st == 200 && rel['kind'] == 'team_reply' && rel['metadata'] == { 'mode' => 'ask', 'relay' => 'pending' } && rel['actor_name'] == agente.available_name
st, claims = api.(admin, :post, 'cases/bot/relays/claims', { inbox_ids: [sem_webhook.id] })
ok 'reserva só nas caixas pedidas', st == 200 && claims['payload'] == []
_, claims = api.(admin, :post, 'cases/bot/relays/claims', { inbox_ids: [inbox.id] })
item = claims['payload'].first
ok 'reserva: texto, modo, conversa, idioma e mensagens recentes', claims['payload'].size == 1 && item['text'].include?('foto') && item['mode'] == 'ask' &&
                                                               item['conversation_id'] == conv.display_id && item['language'] == 'es' &&
                                                               item['messages'].first == { 'from' => 'customer', 'text' => 'Hola' }
_, claims = api.(admin, :post, 'cases/bot/relays/claims', { inbox_ids: [inbox.id] })
ok 'reservado não volta antes de 10 min', claims['payload'] == []
Cases::Event.find(item['event_id']).update!(metadata: { 'mode' => 'ask', 'relay' => 'claimed', 'claimed_at' => 11.minutes.ago.iso8601 })
_, claims = api.(admin, :post, 'cases/bot/relays/claims', { inbox_ids: [inbox.id] })
ok 'reserva vencida volta', claims['payload'].map { |r| r['event_id'] } == [item['event_id']]
st, = api.(admin, :post, "cases/bot/relays/#{item['event_id']}", { sent: true, message: '¿Nos mandas una foto de la cortina?' })
kase.reload
ok 'pergunta enviada: caso espera o cliente', st == 200 && kase.waiting_customer? && kase.paused_at && kase.awaiting_customer_info? &&
                                             Cases::Event.find(item['event_id']).metadata['relay'] == 'sent'
_, ctx = api.(admin, :get, "cases/bot/context?conversation_id=#{conv.display_id}")
ok 'contexto marca a espera da resposta', ctx['open_cases'].find { |c| c['id'] == kase.id }['awaiting_customer_info'] == true

# O cliente responde (pelo Rails, a cada mensagem dele): a foto pedida chega
# sem texto, e o bot não olha mensagem sem texto.
ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::TestAdapter.new
fila = -> { ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j['job_class'] == 'Cases::CustomerReplyJob' } }
png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
foto = conv.messages.new(account: account, inbox: inbox, message_type: :incoming, sender: maria, content: nil)
foto.attachments.new(account: account, file_type: :image, file: { io: StringIO.new(png), filename: 'cortina.png', content_type: 'image/png' })
foto.save!
conv.messages.create!(account: account, inbox: inbox, message_type: :outgoing, private: true, content: 'nota da equipe')
ok 'toda mensagem do cliente vai para o job; nota da equipe não', fila.().map { |j| j['arguments'].first } == [foto.id]
Cases::CustomerReplyJob.perform_now(foto.id)
kase.reload
resp = kase.events.customer_replied.last
ok 'só a foto: vai para o histórico com o anexo, caso volta a andar, equipe avisada',
   kase.in_progress? && resp&.body == '📎 image' && resp.metadata['message_id'] == foto.id &&
   resp.metadata['attachments'].first['type'] == 'image' && resp.metadata['attachments'].first['url'].present? &&
   conv.messages.where(private: true).last(2).any? { |m| m.content.include?('answered the question') }
_, ctx = api.(admin, :get, "cases/bot/context?conversation_id=#{conv.display_id}")
ok 'contexto avisa que o cliente acabou de responder', ctx['open_cases'].find { |c| c['id'] == kase.id }['customer_replied_recently'] == true
texto = conv.messages.create!(account: account, inbox: inbox, message_type: :incoming, sender: maria, content: 'Otra cosa')
Cases::CustomerReplyJob.perform_now(texto.id)
ok 'sem pergunta pendente: nada acontece', kase.events.customer_replied.count == 1
s.post("/api/v1/accounts/#{account.id}/cases/bot/customer_replies", params: { conversation_id: conv.display_id, body: 'x' }.to_json,
                                                                    headers: { 'api_access_token' => admin.access_token.token, 'Content-Type' => 'application/json' })
ok 'rota antiga do bot saiu', s.response.status == 404

api.(agente, :post, "cases/#{kase.id}/relay", { body: 'Ya salió el reemplazo', mode: 'answer' })
_, claims = api.(admin, :post, 'cases/bot/relays/claims', { inbox_ids: [inbox.id] })
api.(admin, :post, "cases/bot/relays/#{claims['payload'][0]['event_id']}", { sent: false })
ok 'repasse que falhou: marcado e quem escreveu é avisado', Cases::Event.find(claims['payload'][0]['event_id']).metadata['relay'] == 'failed' &&
                                                          kase.reload.in_progress? && conv.messages.where(private: true).last.content.include?('could not send')

# Avisos ao cliente (fase 3)
pedro = account.contacts.create!(name: 'Pedro')
conv_p = conversa.(pedro)
st, manual = api.(agente, :post, 'cases', { title: 'Cambio de talla', type_id: problema.id, conversation_id: conv_p.display_id })
aviso = conv_p.messages.outgoing.where(private: false).last
ok 'aberto pela equipe com aviso ligado: número ao cliente, no idioma da conta', st == 200 && aviso&.content.to_s.include?(manual['number']) &&
                                                                               aviso.content.start_with?('Registramos tu solicitud') &&
                                                                               Cases::Event.where(case_id: manual['id']).customer_notified.last.metadata['notice'] == 'opened'
api.(agente, :post, "cases/#{manual['id']}/resolve", { outcome: 'solved' })
ok 'resolvido: aviso ao cliente', conv_p.messages.outgoing.where(private: false).last.content.start_with?("Tu solicitud #{manual['number']} fue resuelta")
duda = tipos[0]
_, sem_aviso = api.(agente, :post, 'cases', { title: 'Pregunta', type_id: duda.id, conversation_id: conv_p.display_id })
ok 'tipo sem aviso: nada ao cliente', Cases::Event.where(case_id: sem_aviso['id']).customer_notified.none? &&
                                      conv_p.messages.outgoing.where(private: false).count == 2
voz = conversa.(pedro, sem_webhook)
_, na_voz = api.(agente, :post, 'cases', { title: 'Llamada', type_id: problema.id, conversation_id: voz.display_id })
ok 'caixa que não entrega: aviso não sai e o histórico diz por quê',
   Cases::Event.where(case_id: na_voz['id']).customer_notified.last.metadata == { 'notice' => 'opened', 'skipped' => 'inbox_does_not_deliver' }
_, sem_conv = api.(agente, :post, 'cases', { title: 'Sin conversación', type_id: problema.id, contact_id: pedro.id })
ok 'sem conversa: aviso registrado como não enviado',
   Cases::Event.where(case_id: sem_conv['id']).customer_notified.last.metadata['skipped'] == 'no_conversation'
st, = api.(agente, :post, "cases/#{sem_conv['id']}/relay", { body: 'Hola', mode: 'answer' })
ok 'repasse sem conversa: 422', st == 422
ok 'Cases::CustomerLabels: pt e en, e idioma desconhecido em inglês',
   Cases::CustomerLabels.text(:opened, 'pt_BR', number: 'X').start_with?('Registramos sua') && Cases::CustomerLabels.normalize('fr') == 'en'

# Métricas
Cases::Case.find(sem_aviso['id']).update!(due_at: 1.hour.ago)
st, m = api.(agente, :get, 'cases/metrics?days=30')
sm = m['summary']
ok 'métricas: abertos, pela IA, resolvidos, ativos e atrasados', st == 200 && sm['opened'] == 6 && sm['opened_by_ai'] == 2 && sm['resolved'] == 1 &&
                                                              sm['active'] == 5 && sm['overdue'] == 1 && sm['on_time_rate'] == 1.0 && sm['avg_resolution_hours']
por_tipo = m['by_type'].to_h { |t| [t['name'], t] }
ok 'métricas por tipo', por_tipo['Problema']['opened'] == 4 && por_tipo['Reclamo']['opened'] == 1 && por_tipo['Duda']['overdue'] == 1
ok 'métricas por responsável (sem responsável incluído)', m['by_assignee'].any? { |a| a['name'].nil? } &&
                                                          m['by_assignee'].find { |a| a['name'] == agente.available_name }['active'] == 1
ok 'período fora do limite vira o mínimo', api.(agente, :get, 'cases/metrics?days=1').last['days'] == 7

account.disable_features!('cases')
ok 'sem a flag: bot recebe 401 (o MontaPrompt segue sem casos)', api.(admin, :get, "cases/bot/context?conversation_id=#{conv.display_id}").first == 401
