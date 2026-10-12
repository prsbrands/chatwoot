# Evolução da IA (AiEvolution::*, /ai_evolution): sinais, reserva, propostas
# com junção de duplicadas e recusadas, aplicar na base e no prompt, conflito,
# desfazer, Progress, flag e permissões, contra Postgres/Redis descartáveis.
# O Supabase do botlayer entra falso, em memória.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

PERSONA = 'aaaaaaaa-0000-4000-8000-000000000001'.freeze
OUTRA = 'aaaaaaaa-0000-4000-8000-000000000002'.freeze
DOC = 'bbbbbbbb-0000-4000-8000-000000000001'.freeze
SB = {
  personas: [{ 'id' => PERSONA, 'slug' => 'nathan', 'display_name' => 'Nathan', 'system_prompt' => "Eres Nathan, asistente de la tienda.\nResponde corto." },
             { 'id' => OUTRA, 'slug' => 'otra', 'display_name' => 'Otra', 'system_prompt' => 'x' }],
  docs: [{ 'id' => DOC, 'slug' => 'horarios', 'title' => 'Horarios y entregas', 'is_active' => true, 'is_global' => false,
           'content' => "### Horario\nLunes a viernes de 9 a 18.\n\n### Entregas\nEntregamos en 5 días hábiles.",
           'bot_persona_knowledge' => [{ 'persona_id' => PERSONA }] }]
}
Integrations::Botlayer::Client.define_singleton_method(:configured?) { true }
Integrations::Botlayer::Client.class_eval do
  def initialize(*); end
  def personas(_account_id) = SB[:personas]
  def knowledge_docs(_account_id) = SB[:docs]
  def update_persona(_account_id, id, attributes) = SB[:personas].find { |p| p['id'] == id }.merge!(attributes.stringify_keys)
  def update_knowledge_doc(_account_id, id, attributes) = SB[:docs].find { |d| d['id'] == id }.merge!(attributes.stringify_keys)

  def create_knowledge_doc(_account_id, attributes)
    doc = attributes.stringify_keys.merge('id' => SecureRandom.uuid, 'bot_persona_knowledge' => [])
    SB[:docs] << doc
    doc
  end

  def set_doc_personas(_account_id, doc_id, persona_ids)
    SB[:docs].find { |d| d['id'] == doc_id }['bot_persona_knowledge'] = persona_ids.map { |id| { 'persona_id' => id } }
  end
end

account = Account.create!(name: 'Evolução', locale: 'es')
account.enable_features!('ai_evolution', 'cases')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@evo.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
agente = User.create!(name: 'Beto Agente', email: "beto-#{SecureRandom.hex(3)}@evo.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: agente, role: :agent)
inbox = account.inboxes.create!(name: 'WhatsApp', channel: Channel::Api.create!(account: account, webhook_url: 'https://openwa.test/hook'))
sem_bot = account.inboxes.create!(name: 'Outra', channel: Channel::Api.create!(account: account))
bot = AgentBot.create!(name: 'CortexGen', outgoing_url: 'https://n8n.test/hook')
AgentBotInbox.create!(inbox: inbox, agent_bot: bot, account: account)

conversa = lambda do |nome, caixa = inbox|
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: caixa, source_id: SecureRandom.uuid)
  Conversation.create!(account: account, inbox: caixa, contact: contact, contact_inbox: ci)
end
fala = ->(conv, tipo, texto, **extra) { conv.messages.create!({ account: account, inbox: conv.inbox, message_type: tipo, content: texto }.merge(extra)) }
nota = ->(conv, texto) { fala.(conv, :outgoing, texto, private: true, sender: bot) }
antigo = ->(conv) { conv.update_columns(last_activity_at: 3.hours.ago) }

# 1) Passagem com resposta da equipe
c1 = conversa.('María')
fala.(c1, :incoming, '¿Hacen envíos a Colón?', sender: c1.contact)
fala.(c1, :outgoing, 'Déjame consultarlo con el equipo.', sender: bot)
nota.(c1, "Traspaso · Por qué el bot traspasó: el cliente pidió una persona\n\nÚltimos mensajes del cliente (sus palabras):\n\"¿Hacen envíos a Colón?\"")
fala.(c1, :outgoing, 'Sí, enviamos a Colón por USD 8, llega en 3 días.', sender: admin)
antigo.(c1)
# 2) Retida pelo Jev, com resposta da equipe
c2 = conversa.('João')
fala.(c2, :incoming, 'Tem desconto para pagamento à vista?', sender: c2.contact)
nota.(c2, "Passagem · Por que o bot passou: o Jev reteve a resposta do bot (Jev): promises something\n\nRascunho retido (envie como está ou reescreva):\n\nSim, 20% de desconto à vista!")
fala.(c2, :outgoing, 'Temos 5% no Pix, só isso.', sender: agente)
antigo.(c2)
# 3) Passagem sem resposta da equipe: não ensina nada ainda
c3 = conversa.('Pedro')
fala.(c3, :incoming, 'quiero hablar con alguien', sender: c3.contact)
nota.(c3, 'Traspaso · Por qué el bot traspasó: el cliente pidió una persona')
antigo.(c3)
# 4) Recente demais (a equipe ainda pode responder)
c4 = conversa.('Lía')
fala.(c4, :incoming, '¿Abren domingo?', sender: c4.contact)
nota.(c4, 'Traspaso · Por qué el bot traspasó: x')
fala.(c4, :outgoing, 'No, domingo cerrado.', sender: admin)
# 5) Caso aberto pela IA com resposta da equipe
c5 = conversa.('Ana')
fala.(c5, :incoming, 'me llegó roto', sender: c5.contact)
tipo = Cases::Type.for(account).second
kase = Cases::CaseFlow.open!(account, { type_id: tipo.id, title: 'me llegó roto', description: 'me llegó roto' }, source: :ai, conversation: c5)
Cases::CaseFlow.new(kase, actor: admin).relay!('Cambiamos sin costo dentro de 30 días.', 'answer')
antigo.(c5)
# 6) Numa caixa sem bot
c6 = conversa.('Zé', sem_bot)
nota.(c6, 'Traspaso · x')
fala.(c6, :outgoing, 'resposta', sender: admin)
antigo.(c6)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/ai_evolution/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end
rotas = { routes: [{ inbox_id: inbox.id, persona_id: PERSONA }, { inbox_id: sem_bot.id, persona_id: PERSONA }] }

# Reserva
st, = api.(agente, :post, 'bot/claims', { routes: [{ inbox_id: inbox.id, persona_id: PERSONA }] })
ok 'agente não usa (401)', st == 401
st, r = api.(admin, :post, 'bot/claims', { routes: [{ inbox_id: inbox.id, persona_id: PERSONA }] })
por = r['payload'].index_by { |c| c['conversation_id'] }
ok 'reserva: passagem respondida, retida e caso da IA; sem resposta e recente ficam fora',
   st == 200 && por.keys.sort == [c1.display_id, c2.display_id, c5.display_id].sort
ok 'sinais certos', por[c1.display_id]['signals'] == ['handoff'] && por[c2.display_id]['signals'] == ['held_reply'] && por[c5.display_id]['signals'] == ['ai_case']
t1 = por[c1.display_id]['transcript']
ok 'conversa com cliente, assistente, equipe e a nota resumida', t1.map { |l| l['from'] } == %w[customer assistant system team] &&
                                                                t1[2]['text'].start_with?('[handed to the team: Traspaso')
ok 'retida: o rascunho entra na nota', por[c2.display_id]['transcript'].find { |l| l['from'] == 'system' }['text'].include?('Held draft: Sim, 20% de desconto')
ok 'caso da IA: título e resposta da equipe', por[c5.display_id]['cases'][0]['team_replies'] == ['Cambiamos sin costo dentro de 30 días.']
p1 = por[c1.display_id]
ok 'persona e base da persona', p1['persona']['name'] == 'Nathan' && p1['knowledge'][0]['content'].include?('5 días hábiles') &&
                                p1['suggestions'] == { 'pending' => [], 'rejected' => [] }
_, r2 = api.(admin, :post, 'bot/claims', rotas)
ok 'reservadas não voltam antes de 1 h; outra caixa com rota entra', r2['payload'].map { |c| c['conversation_id'] } == [c6.display_id]

# Gravar
st, g = api.(admin, :post, 'bot/results', { conversation_id: c1.display_id, last_message_id: p1['last_message_id'], persona_id: PERSONA, persona_name: 'Nathan',
                                            suggestions: [{ kind: 'knowledge_add', title: 'Envíos a Colón', content: 'Enviamos a Colón por USD 8; llega en 3 días.',
                                                            target_doc_id: DOC, rationale: 'El equipo respondió', customer_quote: '¿Hacen envíos a Colón?',
                                                            team_quote: 'Sí, enviamos a Colón por USD 8' },
                                                          { kind: 'knowledge_update', title: 'Entregas', content: 'Entregamos en 3 a 5 días hábiles.',
                                                            target_doc_id: DOC, replace_text: 'Entregamos en 7 días.' }] })
ok 'grava a proposta; correção com trecho que não está na base é descartada', st == 200 && g['saved'].size == 1 &&
                                                                              AiEvolution::Scan.find_by(conversation: c1).claimed_at.nil?
add = AiEvolution::Suggestion.find(g['saved'][0])
ok 'proposta com evidência e o documento', add.knowledge_add? && add.target_doc_title == 'Horarios y entregas' && add.evidence_count == 1 &&
                                           add.evidence[0]['conversation_id'] == c1.display_id && add.evidence[0]['team_quote'].include?('USD 8')
_, g2 = api.(admin, :post, 'bot/results', { conversation_id: c2.display_id, last_message_id: por[c2.display_id]['last_message_id'], persona_id: PERSONA,
                                            suggestions: [{ kind: 'prompt_rule', title: 'No prometer descuentos', content: 'Nunca ofrezcas descuentos que no estén en la base.',
                                                            customer_quote: '¿desconto à vista?', team_quote: 'Temos 5% no Pix' },
                                                          { kind: 'knowledge_update', title: 'Entregas', content: 'Entregamos en 3 a 5 días hábiles.',
                                                            target_doc_id: DOC, replace_text: 'Entregamos en 5 días hábiles.' }] })
regra = AiEvolution::Suggestion.find(g2['saved'][0])
corr = AiEvolution::Suggestion.find(g2['saved'][1])
ok 'regra de prompt e correção com trecho exato', regra.prompt_rule? && regra.target_doc_id.nil? && corr.knowledge_update? && corr.replace_text.present?
_, g3 = api.(admin, :post, 'bot/results', { conversation_id: c5.display_id, last_message_id: por[c5.display_id]['last_message_id'], persona_id: PERSONA,
                                            suggestions: [{ kind: 'knowledge_add', title: 'x', content: 'x', same_as: add.id, customer_quote: 'otro', team_quote: 'otra' }] })
add.reload
ok 'igual a uma pendente: junta a evidência, sem proposta nova', g3['saved'] == [add.id] && add.evidence_count == 2 && account.ai_evolution_suggestions.count == 3

# Tela
st, = api.(agente, :get, 'suggestions')
ok 'agente não vê (401)', st == 401
_, lista = api.(admin, :get, 'suggestions')
ok 'pendentes, a com mais evidência primeiro', lista['payload'].map { |p| p['id'] }.first == add.id && lista['payload'].size == 3
_, conta = api.(admin, :get, 'suggestions/pending_count')
ok 'número do menu', conta['count'] == 3

st, ap = api.(admin, :post, "suggestions/#{add.id}/apply", { content: 'Enviamos a Colón por USD 8. Llega en 3 días hábiles.' })
doc = SB[:docs].find { |d| d['id'] == DOC }
ok 'aplicar trecho novo (editado): seção no fim do documento', st == 200 && ap['status'] == 'applied' && ap['edited'] &&
                                                                doc['content'].end_with?("### Envíos a Colón\nEnviamos a Colón por USD 8. Llega en 3 días hábiles.")
st, = api.(admin, :post, "suggestions/#{add.id}/apply")
ok 'aplicar de novo: 422', st == 422
st, = api.(admin, :post, "suggestions/#{corr.id}/apply")
ok 'correção: troca o trecho exato', st == 200 && doc['content'].include?('Entregamos en 3 a 5 días hábiles.') && !doc['content'].include?('Entregamos en 5 días')
st, = api.(admin, :post, "suggestions/#{regra.id}/apply")
persona = SB[:personas].first
ok 'regra: seção Aprendizados no fim do prompt', st == 200 && persona['system_prompt'].end_with?("## Aprendizados\n- Nunca ofrezcas descuentos que no estén en la base.")

doc['content'] += "\n\nEditado a mano."
st, = api.(admin, :post, "suggestions/#{add.id}/undo")
ok 'desfazer depois de edição alheia: 422', st == 422
st, = api.(admin, :post, "suggestions/#{regra.id}/undo")
ok 'desfazer a regra: prompt volta e proposta fica pendente', st == 200 && persona['system_prompt'] == "Eres Nathan, asistente de la tienda.\nResponde corto." &&
                                                              AiEvolution::Suggestion.find(regra.id).pending?
st, rj = api.(admin, :post, "suggestions/#{regra.id}/reject", { reason: 'Ya está en el manual' })
ok 'recusar com motivo', st == 200 && rj['status'] == 'rejected' && rj['reject_reason'] == 'Ya está en el manual'

# Sem documento escolhido: o "Aprendizados da IA"
semdoc = account.ai_evolution_suggestions.create!(kind: :knowledge_add, persona_id: PERSONA, title: 'Domingos', content: 'Cerramos los domingos.',
                                                   evidence: [], evidence_count: 1)
api.(admin, :post, "suggestions/#{semdoc.id}/apply")
aprend = SB[:docs].find { |d| d['slug'] == 'aprendizados-da-ia' }
ok 'trecho sem documento vai para "Aprendizados da IA", ligado à persona', aprend && aprend['content'] == "### Domingos\nCerramos los domingos." &&
                                                                           aprend['bot_persona_knowledge'].map { |l| l['persona_id'] } == [PERSONA]
# Recusadas e pendentes voltam para a rodada seguinte
fala.(c1, :incoming, '¿Y a Chiriquí?', sender: c1.contact)
nota.(c1, 'Traspaso · otra vez')
fala.(c1, :outgoing, 'A Chiriquí USD 12.', sender: admin)
antigo.(c1)
_, r3 = api.(admin, :post, 'bot/claims', rotas)
volta = r3['payload'].find { |c| c['conversation_id'] == c1.display_id }
ok 'sinal novo na mesma conversa volta, só com o trecho novo', volta && volta['transcript'].first['text'] == '¿Y a Chiriquí?'
ok 'a rodada recebe as recusadas com o motivo', volta['suggestions']['rejected'] == [{ 'title' => 'No prometer descuentos', 'reason' => 'Ya está en el manual' }]

# Progress
_, pr = api.(admin, :get, 'suggestions/progress')
semana = pr['payload'].last
ok 'Progress: 12 semanas, conversas, passagens, retidas, casos da IA e aplicadas', pr['payload'].size == 12 &&
                                                                               semana['conversations'] >= 5 && semana['handoffs'] == 5 && semana['held'] == 1 &&
                                                                               semana['ai_cases'] == 1 && semana['applied'] == 3

account.disable_features!('ai_evolution')
ok 'sem a flag: 401', api.(admin, :get, 'suggestions').first == 401
