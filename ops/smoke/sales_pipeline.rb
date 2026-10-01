# Roda dentro da :test-b5 contra um Postgres descartavel (schema novo).
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Teste Funil', locale: 'es')
account.enable_features!('sales_pipeline')
ok 'flag sales_pipeline ligada', account.feature_enabled?('sales_pipeline')

pipeline = Sales::Pipeline.default_for(account)
ok 'funil padrao em espanhol', pipeline.name == 'Ventas' && pipeline.stages.first.name == 'Nuevo contacto'
ok '7 etapas, ganho e perda', pipeline.stages.count == 7 && pipeline.stages.won.count == 1 && pipeline.stages.lost.count == 1
ok 'passo do agente nas 5 abertas', pipeline.stages.open.pluck(:agent_step) == %w[new contacted qualifying qualified negotiating]
ok 'default_for nao duplica', Sales::Pipeline.default_for(account).id == pipeline.id && account.sales_pipelines.count == 1

contact = account.contacts.create!(name: 'Ana Lopez', phone_number: '+50760000000')
deal = Sales::Deal.open_for_contact!(contact, conversation: nil)
ok 'negocio aberto na 1a etapa', deal.open? && deal.stage == pipeline.first_open_stage && deal.title == 'Ana Lopez'
ok 'moeda USD em conta es', deal.currency == 'USD'
ok 'transicao de criacao (system)', deal.transitions.count == 1 && deal.transitions.first.actor_type == 'system'
ok 'open_for_contact! nao duplica', Sales::Deal.open_for_contact!(contact, conversation: nil).id == deal.id && account.sales_deals.count == 1

# Rajada: tres threads ao mesmo tempo, um negocio so (o lock por contato).
contact2 = account.contacts.create!(name: 'Rajada')
3.times.map { Thread.new { ActiveRecord::Base.connection_pool.with_connection { Sales::Deal.open_for_contact!(contact2.reload, conversation: nil) } } }.each(&:join)
ok 'rajada de 3 = 1 negocio', account.sales_deals.where(contact: contact2).count == 1

user = User.create!(name: 'Agente', email: "agente#{SecureRandom.hex(3)}@ex.com", password: 'Senha!1234Aa', confirmed_at: Time.current)
proposta = pipeline.stages.find_by(agent_step: 'qualified')
deal.move_to!(proposta, actor: user, reason: 'pediu orçamento')
ok 'mover registra autor e motivo', deal.reload.stage == proposta && deal.transitions.first.actor_type == 'user' && deal.transitions.first.reason == 'pediu orçamento'

perda = pipeline.stages.lost.first
falhou = begin; deal.move_to!(perda, actor: user); false; rescue ActiveRecord::RecordInvalid; true; end
ok 'perda sem motivo e recusada', falhou && deal.reload.open?
deal.move_to!(perda, actor: user, lost_reason: 'preço')
ok 'perda com motivo fecha', deal.reload.lost? && deal.closed_at.present? && deal.lost_reason == 'preço'
deal.move_to!(pipeline.first_open_stage, actor: user)
ok 'voltar reabre e limpa o motivo', deal.reload.open? && deal.closed_at.nil? && deal.lost_reason.nil?
ok 'motivo da perda fica no historico', deal.transitions.where(reason: 'preço').exists?
ok 'historico com 4 transicoes', deal.transitions.count == 4

p2 = Sales::Pipeline.create_with_template!(account, name: 'Parcerias')
ok 'funil novo com etapas-modelo, nao padrao', p2.stages.count == 7 && !p2.is_default && p2.position > pipeline.position
p2.make_default!
ok 'trocar o padrao desmarca o anterior', p2.reload.is_default && !pipeline.reload.is_default && account.sales_pipelines.where(is_default: true).count == 1
deal.move_to!(p2.first_open_stage, actor: user, reason: 'outro funil')
ok 'negocio vai para outro funil', deal.reload.pipeline_id == p2.id && deal.stage.pipeline_id == p2.id && deal.transitions.first.reason == 'outro funil'
c5 = account.contacts.create!(name: 'Novo padrao')
ok 'automatico nasce no novo padrao', Sales::Deal.open_for_contact!(c5, conversation: nil).pipeline_id == p2.id
pipeline.make_default!
ok 'etapa com negocio nao apaga', !pipeline.first_open_stage.destroy && Sales::Stage.exists?(pipeline.first_open_stage.id)
pt = Account.create!(name: 'Conta BR', locale: 'pt_BR')
ok 'conta pt: Vendas, BRL', Sales::Pipeline.default_for(pt).stages.first.name == 'Novo contato' && Sales::Pipeline.currency_for(pt) == 'BRL'

# Listener: mensagem do cliente numa inbox com bot abre o negocio.
channel = Channel::Api.create!(account: account)
inbox = account.inboxes.create!(name: 'WA', channel: channel)
bot = AgentBot.create!(name: 'Bot', account: account)
AgentBotInbox.create!(inbox: inbox, agent_bot: bot, status: :active)
contact3 = account.contacts.create!(name: 'Via mensagem')
ci = ContactInbox.create!(contact: contact3, inbox: inbox, source_id: SecureRandom.uuid)
conv = Conversation.create!(account: account, inbox: inbox, contact: contact3, contact_inbox: ci)
msg = conv.messages.create!(account: account, inbox: inbox, sender: contact3, message_type: :incoming, content: 'hola')
SalesDealListener.instance.message_created(Events::Base.new('message.created', Time.zone.now, message: msg))
d3 = account.sales_deals.find_by(contact: contact3)
ok 'listener abre negocio ligado a conversa', d3.present? && d3.conversation_id == conv.id

account.disable_features!('sales_pipeline')
contact4 = account.contacts.create!(name: 'Flag off')
ci4 = ContactInbox.create!(contact: contact4, inbox: inbox, source_id: SecureRandom.uuid)
conv4 = Conversation.create!(account: account, inbox: inbox, contact: contact4, contact_inbox: ci4)
msg4 = conv4.messages.create!(account: account, inbox: inbox, sender: contact4, message_type: :incoming, content: 'oi')
SalesDealListener.instance.message_created(Events::Base.new('message.created', Time.zone.now, message: msg4))
ok 'flag desligada nao abre negocio', !account.sales_deals.exists?(contact: contact4)

# Views e rotas carregam
ok 'rotas do funil', Rails.application.routes.url_helpers.respond_to?(:api_v1_account_sales_deals_path)
puts ApplicationController.render(template: 'api/v1/accounts/sales/deals/show', formats: [:json], assigns: { deal: deal.reload })[0, 160]
