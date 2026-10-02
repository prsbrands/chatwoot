# Radar de risco (Sales::Radar e GET /sales/radar) contra Postgres/Redis
# descartaveis. O Supabase e falso: rotas, personas e series de follow-up vem
# de FAKE, para nao depender do botlayer de verdade.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

FAKE = { routes: [], personas: [], followups: [] }.freeze
Integrations::Botlayer::Client.class_eval do
  def initialize(*); end
  def routes(_account_id) = FAKE[:routes]
  def personas(_account_id) = FAKE[:personas]
  def followups(_account_id, ids) = FAKE[:followups].select { |s| ids.include?(s['chatwoot_conversation_id']) }
end

account = Account.create!(name: 'Radar', locale: 'es')
account.enable_features!('sales_pipeline', 'bot_personas')
user = User.create!(name: 'Ana Vendas', email: "ana-#{SecureRandom.hex(3)}@radar.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: user, role: :administrator)
bot = AgentBot.create!(name: 'Nathan', outgoing_url: 'http://bot.invalid/webhook', account: account)

openwa = account.inboxes.create!(name: 'WA QR', channel: Channel::Api.create!(account: account), timezone: 'America/Bogota')
AgentBotInbox.create!(inbox: openwa, agent_bot: bot, status: :active, account: account)
# Sem bot: com bot ligado, o Chatwoot cria toda conversa como pendente com ele.
site = account.inboxes.create!(name: 'Site', channel: Channel::Api.create!(account: account), timezone: 'America/Bogota')
sem_fuso = account.inboxes.create!(name: 'WA UTC', channel: Channel::Api.create!(account: account))
AgentBotInbox.create!(inbox: sem_fuso, agent_bot: bot, status: :active, account: account)

FAKE[:personas] << { 'id' => 'p1', 'followup_after_hours' => 48, 'max_followups' => 2 }
FAKE[:routes] << { 'chatwoot_inbox_id' => openwa.id, 'persona_id' => 'p1', 'is_active' => true, 'split_replies' => true }
FAKE[:routes] << { 'chatwoot_inbox_id' => sem_fuso.id, 'persona_id' => 'p1', 'is_active' => true, 'split_replies' => true }

# Conversa com o cliente escrevendo ha `cliente_h` horas e, se `bot_h`, o bot
# respondendo depois, ha `bot_h` horas.
def negocio(account, inbox, nome, cliente_h:, bot_h: nil, status: :open)
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci, status: status)
  m = conv.messages.create!(account: account, inbox: inbox, sender: contact, message_type: :incoming, content: 'quiero precio')
  m.update_columns(created_at: cliente_h.hours.ago)
  if bot_h
    r = conv.messages.create!(account: account, inbox: inbox, message_type: :outgoing, content: 'Te paso la propuesta')
    r.update_columns(created_at: bot_h.hours.ago)
  end
  [Sales::Deal.open_for_contact!(contact, conversation: conv), conv]
end

critico, = negocio(account, site, 'Critico sem dono', cliente_h: 100)
com_ana, = negocio(account, openwa, 'Em risco com Ana', cliente_h: 30)
com_ana.update!(assignee: user)
em_voo, conv_voo = negocio(account, openwa, 'Em voo', cliente_h: 31, bot_h: 30, status: :pending)
esgotado, conv_esg = negocio(account, openwa, 'Serie esgotada', cliente_h: 31, bot_h: 30, status: :pending)
no_teto, conv_teto = negocio(account, openwa, 'Serie no teto', cliente_h: 31, bot_h: 30, status: :pending)
utc, = negocio(account, sem_fuso, 'Inbox sem fuso', cliente_h: 31, bot_h: 30, status: :pending)
velho, = negocio(account, openwa, 'Cliente sumido ha 8 dias', cliente_h: 200, bot_h: 199, status: :pending)
em_dia, = negocio(account, openwa, 'Em dia', cliente_h: 2)

ancora = ->(conv) { conv.messages.incoming.reorder(:created_at).last.id }
FAKE[:followups] << { 'chatwoot_conversation_id' => conv_voo.display_id, 'anchor_message_id' => ancora.(conv_voo), 'status' => 'active', 'attempts' => 1 }
FAKE[:followups] << { 'chatwoot_conversation_id' => conv_esg.display_id, 'anchor_message_id' => ancora.(conv_esg), 'status' => 'exhausted', 'attempts' => 2 }
FAKE[:followups] << { 'chatwoot_conversation_id' => conv_teto.display_id, 'anchor_message_id' => ancora.(conv_teto), 'status' => 'active', 'attempts' => 2 }

Sales::RiskSweepJob.perform_now
rows = Sales::Radar.new(account).rows.index_by { |row| row[:deal].id }

ok 'em dia fica fora', !rows.key?(em_dia.id)
ok 'critico sem dono', rows[critico.id] && rows[critico.id][:bucket] == 'critical' && rows[critico.id][:owner] == { type: 'none' }
ok 'em risco com a Ana (dono do negocio)', rows[com_ana.id] && rows[com_ana.id][:bucket] == 'at_risk' && rows[com_ana.id][:owner] == { type: 'user', name: 'Ana Vendas' }
voo = rows[em_voo.id]
ok 'em voo: bot retoma em 18 h', voo && voo[:bucket] == 'in_flight' && voo[:owner] == { type: 'bot', name: 'Nathan' } &&
                                 (voo[:followup_at] - 18.hours.from_now.to_i).abs < 120
ok 'serie esgotada: depende da equipe', rows[esgotado.id] && rows[esgotado.id][:bucket] == 'at_risk' && rows[esgotado.id][:followup_at].nil?
ok 'serie no teto: depende da equipe', rows[no_teto.id] && rows[no_teto.id][:bucket] == 'at_risk'
ok 'inbox em UTC: sem follow-up', rows[utc.id] && rows[utc.id][:bucket] == 'at_risk' && rows[utc.id][:owner][:type] == 'bot'
ok 'cliente sumido ha mais de 7 dias: sem follow-up', rows[velho.id] && rows[velho.id][:bucket] == 'critical'

conv_voo.contact.update!(blocked: true)
ok 'contato bloqueado: sem follow-up', Sales::Radar.new(account).rows.find { |r| r[:deal].id == em_voo.id }[:bucket] == 'at_risk'
conv_voo.contact.update!(blocked: false)

ordem = Sales::Radar.new(account).rows.map { |row| row[:bucket] }
ok 'ordem: critico, em risco, em voo', ordem == ordem.sort_by { |b| Sales::Radar::BUCKETS.index(b) }

account.disable_features!('bot_personas')
ok 'conta sem personas: ninguem em voo', Sales::Radar.new(account).rows.none? { |row| row[:bucket] == 'in_flight' }
account.enable_features!('bot_personas')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
s.get "/api/v1/accounts/#{account.id}/sales/radar", headers: { 'api_access_token' => user.access_token.token }
body = JSON.parse(s.response.body)
ok 'API: 200 com as contagens', s.response.status == 200 && body['counts'] == { 'critical' => 2, 'at_risk' => 4, 'in_flight' => 1 }
primeiro = body['payload'].first
ok 'API: linha com negocio, etapa e dono', primeiro['bucket'] == 'critical' && primeiro.dig('deal', 'stage_name').present? &&
                                          primeiro.dig('deal', 'insight', 'risk') == 'critical' && primeiro['owner'].key?('type')

account.disable_features!('sales_pipeline')
s.get "/api/v1/accounts/#{account.id}/sales/radar", headers: { 'api_access_token' => user.access_token.token }
ok 'API: sem a flag do funil = 401', s.response.status == 401
