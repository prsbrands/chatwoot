# Tarefas (Sales::Task e /sales/tasks) e o "sem próximo passo" do Radar,
# contra Postgres/Redis descartaveis.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Tarefas', locale: 'es')
account.enable_features!('sales_pipeline')
outra = Account.create!(name: 'Outra conta')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@tarefas.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
agente = User.create!(name: 'Beto Agente', email: "beto-#{SecureRandom.hex(3)}@tarefas.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: agente, role: :agent)
inbox = account.inboxes.create!(name: 'Site', channel: Channel::Api.create!(account: account))

def negocio(account, inbox, nome)
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
  Sales::Deal.open_for_contact!(contact, conversation: conv)
end
d1 = negocio(account, inbox, 'Com tarefa no negocio')
d2 = negocio(account, inbox, 'Com tarefa so no contato')
d3 = negocio(account, inbox, 'Sem proximo passo')
d4 = negocio(account, inbox, 'So tarefa concluida')
contato_de_fora = outra.contacts.create!(name: 'De outra conta')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/sales/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

st, t1 = api.(agente, :post, 'tasks', { title: 'Mandar proposta', deal_id: d1.id, due_at: 2.hours.ago.iso8601 })
ok 'criar: 200, responsavel = quem criou, contato herdado do negocio', st == 200 && t1.dig('assignee', 'id') == agente.id && t1.dig('contact', 'id') == d1.contact_id && t1.dig('deal', 'id') == d1.id
st, = api.(agente, :post, 'tasks', { title: 'Ligar de volta', contact_id: d2.contact_id })
ok 'tarefa so do contato', st == 200
st, = api.(admin, :post, 'tasks', { title: 'Avulsa sem nada', assignee_id: admin.id })
ok 'tarefa avulsa (sem negocio nem contato)', st == 200
_, t4 = api.(admin, :post, 'tasks', { title: 'Ja feita', deal_id: d4.id })
st, = api.(admin, :post, 'tasks', { title: '' })
ok 'sem titulo: 422', st == 422
st, = api.(admin, :post, 'tasks', { title: 'Invasora', contact_id: contato_de_fora.id })
ok 'contato de outra conta: 404', st == 404

st, t4 = api.(admin, :patch, "tasks/#{t4['id']}", { completed: true })
ok 'concluir grava quando', st == 200 && t4['completed_at'].present?

_, pend = api.(admin, :get, 'tasks')
ok 'pendentes: 3, a vencida primeiro e a sem prazo no fim', pend['payload'].size == 3 && pend['payload'].first['title'] == 'Mandar proposta' && pend['payload'].last['due_at'].nil?
_, minhas = api.(agente, :get, 'tasks?assignee_id=me')
ok 'filtro "minhas"', minhas['payload'].map { |t| t['title'] }.sort == ['Ligar de volta', 'Mandar proposta']
_, feitas = api.(admin, :get, 'tasks?status=done')
ok 'concluidas', feitas['payload'].map { |t| t['title'] } == ['Ja feita']
_, do_negocio = api.(admin, :get, "tasks?deal_id=#{d1.id}")
ok 'por negocio', do_negocio['payload'].map { |t| t['title'] } == ['Mandar proposta']

sem_passo = Sales::Radar.new(account).without_next_step.map(&:id)
ok 'sem proximo passo: so os que nao tem tarefa pendente (avulsa nao zera a lista)', sem_passo.sort == [d3.id, d4.id].sort

st, = api.(agente, :delete, "tasks/#{t4['id']}")
ok 'agente nao apaga tarefa de outro: 401', st == 401
st, = api.(agente, :delete, "tasks/#{t1['id']}")
ok 'agente apaga a propria', st == 200 && !Sales::Task.exists?(t1['id'])
_, t4 = api.(admin, :patch, "tasks/#{t4['id']}", { completed: false })
ok 'reabrir limpa quando e quem', t4['completed_at'].nil? && Sales::Task.find(t4['id']).completed_by_id.nil?

d4.destroy!
ok 'apagar o negocio apaga as tarefas dele', !Sales::Task.exists?(t4['id'])
contato = d3.contact
Sales::Task.create!(account: account, title: 'Do contato', contact: contato)
contato.destroy!
Sales::Deal.where(contact_id: contato.id).find_each(&:destroy!) # o destroy_async, aqui na hora
ok 'apagar o contato apaga tarefas e negocios dele', Sales::Task.where(contact_id: contato.id).none? && Sales::Deal.where(contact_id: contato.id).none?
ok 'Kanban continua lendo os negocios', api.(admin, :get, "deals?pipeline_id=#{d1.pipeline_id}").first == 200

account.disable_features!('sales_pipeline')
ok 'sem a flag do funil: 401', api.(admin, :get, 'tasks').first == 401
