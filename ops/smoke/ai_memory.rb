# Memória da IA por contato (AiMemory, /ai_memory/...): a reserva das conversas
# paradas, a gravação do que o LLM devolve, a leitura para o prompt, a tela e a
# junção de contatos, contra Postgres/Redis descartaveis.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Memoria', locale: 'es')
outra = Account.create!(name: 'Outra conta')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@mem.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
agente = User.create!(name: 'Beto Agente', email: "beto-#{SecureRandom.hex(3)}@mem.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: agente, role: :agent)
wa = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account))
site = account.inboxes.create!(name: 'Site', channel: Channel::Api.create!(account: account))
sem_bot = account.inboxes.create!(name: 'Sem bot', channel: Channel::Api.create!(account: account))

def conversa(account, inbox, contact, falas, parada_ha: 40.minutes)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
  falas.each do |quem, texto|
    conv.messages.create!(account: account, inbox: inbox, sender: (quem == :c ? contact : nil),
                          message_type: (quem == :c ? :incoming : :outgoing), content: texto)
  end
  conv.update_columns(last_activity_at: parada_ha.ago)
  conv
end

maria = account.contacts.create!(name: 'Maria Lopez')
c1 = conversa(account, wa, maria, [[:c, 'Hola, tengo 3 tiendas en Colon'], [:b, 'Que bueno! En que te ayudo?'], [:c, 'Quiero el plan anual']])
c1.messages.create!(account: account, inbox: wa, message_type: :outgoing, private: true, content: 'nota interna, nao entra')
c1.update_columns(last_activity_at: 40.minutes.ago)
ativa = conversa(account, wa, account.contacts.create!(name: 'Falando agora'), [[:c, 'oi']], parada_ha: 5.minutes)
velha = conversa(account, wa, account.contacts.create!(name: 'Sumiu faz tempo'), [[:c, 'oi']], parada_ha: 10.days)
so_bot = conversa(account, wa, account.contacts.create!(name: 'So o bot falou'), [[:b, 'Hola!']])
fora = conversa(account, sem_bot, account.contacts.create!(name: 'Caixa sem bot'), [[:c, 'oi']])

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil, conta: account|
  s.public_send(verb, "/api/v1/accounts/#{conta.id}/ai_memory/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end
bot_inboxes = [wa.id, site.id]

ok 'agente nao reserva conversas: 401', api.(agente, :post, 'bot/claims', { inbox_ids: bot_inboxes }).first == 401
st, r = api.(admin, :post, 'bot/claims', { inbox_ids: bot_inboxes })
lista = r['payload']
ok 'reserva: so a conversa parada ha 30 min com fala nova do cliente', st == 200 && lista.map { |i| i['conversation_id'] } == [c1.display_id]
item = lista.first
ok 'reserva: mensagens publicas em ordem, sem nota, com quem falou', item['messages'].map { |m| m['from'] } == %w[customer business customer] &&
                                                                       item['messages'].last['text'] == 'Quiero el plan anual' && item['earlier'] == []
ok 'reserva: contato, resumo vazio, sem fatos, ultima mensagem', item['contact_id'] == maria.id && item['contact_name'] == 'Maria Lopez' &&
                                                                  item['summary'] == '' && item['facts'] == [] &&
                                                                  item['last_message_id'] == c1.messages.where(private: false).maximum(:id)
ok 'reservada: nao volta na rodada seguinte', api.(admin, :post, 'bot/claims', { inbox_ids: bot_inboxes })[1]['payload'] == []
ok 'sem inbox_ids: 422', api.(admin, :post, 'bot/claims', {}).first == 422

st, = api.(admin, :post, 'bot/updates', { contact_id: maria.id, conversation_id: c1.display_id, last_message_id: item['last_message_id'],
                                          summary: 'Duena de 3 tiendas en Colon; quiere el plan anual.',
                                          add: ['Tiene 3 tiendas en Colon', 'Quiere el plan anual', 'tiene 3 tiendas en colón', ''] })
memoria = AiMemory::Summary.find_by(contact: maria)
ok 'grava: resumo, leitura ate a ultima, reserva solta', st == 200 && memoria.body.start_with?('Duena de 3') &&
                                                         memoria.last_message_id == item['last_message_id'] && memoria.claimed_at.nil? && memoria.refreshed_at
ok 'grava: fatos sem repetido nem vazio, da IA, com a conversa', AiMemory::Fact.where(contact: maria).ai.pluck(:body).sort == ['Quiere el plan anual', 'Tiene 3 tiendas en Colon'] &&
                                                                 AiMemory::Fact.where(contact: maria).all? { |f| f.conversation_id == c1.id }
ok 'sem mensagem nova: nao reserva mais', api.(admin, :post, 'bot/claims', { inbox_ids: bot_inboxes })[1]['payload'] == []

# --- a tela ------------------------------------------------------------------
st, tela = api.(agente, :get, "contacts/#{maria.id}")
ok 'tela: agente ve resumo e fatos', st == 200 && tela['summary'].start_with?('Duena') && tela['facts'].size == 2 && tela['refreshed_at']
anual = tela['facts'].find { |f| f['body'] == 'Quiere el plan anual' }
st, fixado = api.(agente, :patch, "facts/#{anual['id']}", { pinned: true })
ok 'fixar: continua da IA, agora fixado', st == 200 && fixado['pinned'] && fixado['source'] == 'ai'
tiendas = tela['facts'].find { |f| f['body'].start_with?('Tiene 3') }
st, corrigido = api.(agente, :patch, "facts/#{tiendas['id']}", { body: 'Tiene 4 tiendas en Colon' })
ok 'corrigir pela tela: vira manual, de quem corrigiu', st == 200 && corrigido['source'] == 'manual' && AiMemory::Fact.find(tiendas['id']).created_by == agente
st, manual = api.(agente, :post, 'facts', { contact_id: maria.id, body: 'Prefiere hablar despues de las 18h' })
ok 'fato manual pela tela', st == 200 && manual['source'] == 'manual' && !manual['pinned']
ok 'fato vazio: 422', api.(agente, :post, 'facts', { contact_id: maria.id, body: ' ' }).first == 422
ok 'fato de contato de outra conta: 404', api.(agente, :post, 'facts', { contact_id: outra.contacts.create!(name: 'X').id, body: 'x' }).first == 404
ok 'tela: fixado primeiro', api.(agente, :get, "contacts/#{maria.id}")[1]['facts'].first['id'] == anual['id']
st, = api.(agente, :patch, "contacts/#{maria.id}", { summary: 'Duena de 4 tiendas en Colon.' })
ok 'editar o resumo pela tela', st == 200 && memoria.reload.body == 'Duena de 4 tiendas en Colon.'

# --- a IA nao mexe no que e da pessoa ----------------------------------------
c1.messages.create!(account: account, inbox: wa, sender: maria, message_type: :incoming, content: 'Mejor el mensual, y ya no tengo tiendas')
c1.update_columns(last_activity_at: 35.minutes.ago)
item = api.(admin, :post, 'bot/claims', { inbox_ids: bot_inboxes })[1]['payload'].first
ok 'nova fala: reserva so a mensagem nova, com as anteriores de contexto', item && item['messages'].map { |m| m['text'] } == ['Mejor el mensual, y ya no tengo tiendas'] &&
                                                                         item['earlier'].size == 3
ok 'nova fala: fatos com locked', item['facts'].all? { |f| f['locked'] } && item['facts'].size == 3 && item['summary'] == 'Duena de 4 tiendas en Colon.'
ids = AiMemory::Fact.where(contact: maria).pluck(:id)
api.(admin, :post, 'bot/updates', { contact_id: maria.id, last_message_id: item['last_message_id'], summary: 'Quiere el plan mensual.',
                                    remove: ids, update: ids.map { |id| { id: id, text: 'mudado pela IA' } }, add: ['Quiere el plan mensual'] })
ok 'IA nao apaga nem muda fato manual ou fixado', AiMemory::Fact.where(id: ids).count == 3 && AiMemory::Fact.where(body: 'mudado pela IA').none?
ok 'IA acrescenta o novo', AiMemory::Fact.where(contact: maria, body: 'Quiere el plan mensual').exists?

livre = AiMemory::Fact.create!(contact: maria, account: account, body: 'Vai viajar em dezembro', source: :ai)
api.(admin, :post, 'bot/updates', { contact_id: maria.id, last_message_id: item['last_message_id'], summary: 'x',
                                    update: [{ id: livre.id, text: 'Vai viajar em janeiro' }] })
ok 'IA corrige o proprio fato', livre.reload.body == 'Vai viajar em janeiro'
api.(admin, :post, 'bot/updates', { contact_id: maria.id, last_message_id: item['last_message_id'], summary: 'x', remove: [livre.id] })
ok 'IA apaga o proprio fato', !AiMemory::Fact.exists?(livre.id)
ok 'leitura nao volta para tras', memoria.reload.last_message_id == item['last_message_id']

40.times { |n| AiMemory::Fact.create!(contact: maria, account: account, body: "fato #{n}", source: :ai, created_at: (100 - n).minutes.ago) }
api.(admin, :post, 'bot/updates', { contact_id: maria.id, last_message_id: item['last_message_id'], summary: 'x', add: ['mais um'] })
fatos = AiMemory::Fact.where(contact: maria)
ok 'teto de 30: saem os mais antigos da IA, ficam os da pessoa', fatos.count == AiMemory::Bot::MAX_FACTS && fatos.where(id: ids).count == 3 &&
                                                               fatos.exists?(body: 'mais um') && !fatos.exists?(body: 'fato 0')
ok 'gravar sem contact_id: 422', api.(admin, :post, 'bot/updates', { last_message_id: 1, summary: 'x' }).first == 422
ok 'gravar contato de outra conta: 404', api.(admin, :post, 'bot/updates', { contact_id: outra.contacts.first.id, last_message_id: 1, summary: 'x' }).first == 404

# --- o prompt ------------------------------------------------------------------
c_site = conversa(account, site, maria, [[:c, 'hola de nuevo']], parada_ha: 1.minute)
st, prompt = api.(admin, :get, "bot/contact?conversation_id=#{c_site.display_id}")
ok 'prompt: a memoria vale em outro canal do mesmo contato, fixado primeiro', st == 200 && prompt['summary'] == 'x' &&
                                                                              prompt['facts'].first == 'Quiere el plan anual' && prompt['facts'].size == 30
st, vazio = api.(admin, :get, "bot/contact?conversation_id=#{ativa.display_id}")
ok 'prompt: contato sem memoria', st == 200 && vazio == { 'summary' => '', 'facts' => [] }
ok 'prompt: conversa de outra conta: 404', api.(admin, :get, "bot/contact?conversation_id=#{fora.display_id}", conta: outra).first.in?([401, 404])

# --- reserva: um contato por rodada, a falha volta depois de 1 h ---------------
joao = account.contacts.create!(name: 'Joao')
j1 = conversa(account, wa, joao, [[:c, 'oi pelo whatsapp']])
j2 = conversa(account, site, joao, [[:c, 'oi pelo site']])
lista = api.(admin, :post, 'bot/claims', { inbox_ids: bot_inboxes })[1]['payload']
ok 'duas conversas do mesmo contato: uma por rodada', lista.count { |i| i['contact_id'] == joao.id } == 1
AiMemory::Summary.find_by(contact: joao).update_columns(claimed_at: 61.minutes.ago)
ok 'LLM falhou: a reserva vence em 1 h e volta', api.(admin, :post, 'bot/claims', { inbox_ids: bot_inboxes })[1]['payload'].any? { |i| i['contact_id'] == joao.id }
ok 'limite da rodada', api.(admin, :post, 'bot/claims', { inbox_ids: [wa.id, site.id, sem_bot.id], limit: 1 })[1]['payload'].size <= 1
_ = [ativa, velha, so_bot, j1, j2]

# --- juntar contatos ---------------------------------------------------------
joao_fatos = AiMemory::Fact.create!(contact: joao, account: account, body: 'Joao tem um restaurante', source: :ai)
AiMemory::Summary.find_by(contact: joao).update!(body: 'Joao, restaurante.', last_message_id: 1)
account.enable_features!('sales_pipeline')
deal = Sales::Deal.open_for_contact!(joao, conversation: j1)
tarefa = Sales::Task.create!(account: account, contact: joao, title: 'Ligar')
ContactMergeAction.new(account: account, base_contact: maria, mergee_contact: joao).perform
ok 'juntar: fatos do absorvido passam', joao_fatos.reload.contact_id == maria.id
junto = AiMemory::Summary.find_by(contact: maria)
ok 'juntar: resumos lado a lado, leitura volta ao mais antigo', junto.body == "x\n\nJoao, restaurante." && junto.last_message_id == 1 &&
                                                              !AiMemory::Summary.exists?(contact_id: joao.id)
ok 'juntar: negocio e tarefa passam (antes eram apagados)', deal.reload.contact_id == maria.id && tarefa.reload.contact_id == maria.id

so_memoria = account.contacts.create!(name: 'So memoria')
AiMemory::Summary.create!(contact: so_memoria, account: account, body: 'resumo dele')
sem_nada = account.contacts.create!(name: 'Sem nada')
ContactMergeAction.new(account: account, base_contact: sem_nada, mergee_contact: so_memoria).perform
ok 'juntar com quem nao tinha memoria: o resumo muda de dono', AiMemory::Summary.find_by(contact: sem_nada)&.body == 'resumo dele'

maria.destroy!
ok 'excluir contato apaga a memoria', !AiMemory::Fact.exists?(contact_id: maria.id) && !AiMemory::Summary.exists?(contact_id: maria.id)
