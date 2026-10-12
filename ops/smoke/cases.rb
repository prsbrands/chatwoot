# Casos (Cases::*, /cases e /cases/types): tipos do modelo, campos próprios,
# prazo e pausa, situações, histórico, filtros, Radar e juntar contatos,
# contra Postgres/Redis descartáveis.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Casos', locale: 'es')
account.enable_features!('cases')
outra = Account.create!(name: 'Outra conta')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@casos.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
agente = User.create!(name: 'Beto Agente', email: "beto-#{SecureRandom.hex(3)}@casos.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)
AccountUser.create!(account: account, user: agente, role: :agent)
inbox = account.inboxes.create!(name: 'Site', channel: Channel::Api.create!(account: account))

conversa = lambda do |contact|
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
end
maria = account.contacts.create!(name: 'María Peña')
conv1 = conversa.(maria)
joao = account.contacts.create!(name: 'João')
conv2 = conversa.(joao)
de_fora = outra.contacts.create!(name: 'De outra conta')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |user, verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

# Tipos
st, tipos = api.(agente, :get, 'cases/types')
nomes = tipos['payload'].map { |t| t['name'] }
ok 'modelo no idioma da conta (es), 5 tipos', st == 200 && nomes == %w[Duda Problema Solicitud Reclamo Financiero]
api.(agente, :get, 'cases/types')
ok 'ler de novo não duplica o modelo', account.cases_types.count == 5
st, = api.(agente, :post, 'cases/types', { name: 'Do agente' })
ok 'agente não cria tipo: 401', st == 401
st, = api.(admin, :post, 'cases/types', { name: 'Ruim', fields: [{ key: 'Nº pedido', label: 'Pedido', type: 'text' }] })
ok 'campo com chave inválida: 422', st == 422
st, = api.(admin, :post, 'cases/types', { name: 'Ruim', fields: [{ key: 'cor', label: 'Cor', type: 'select', options: [] }] })
ok 'lista sem opções: 422', st == 422
campos = [{ key: 'pedido', label: 'Nº do pedido', type: 'text', required: true },
          { key: 'valor', label: 'Valor', type: 'number' },
          { key: 'motivo', label: 'Motivo', type: 'select', options: %w[Atraso Defeito] },
          { key: 'entrega', label: 'Entrega', type: 'date' },
          { key: 'urgente', label: 'Urgente', type: 'boolean' }]
st, troca = api.(admin, :post, 'cases/types', { name: 'Troca', sla_hours: 10, default_priority: 'high', default_assignee_id: agente.id,
                                                  fields: campos, ai_mode: 'continue' })
ok 'admin cria tipo com campos, prazo e padrões', st == 200 && troca['fields'].size == 5 && troca['position'] == 5 && troca['ai_mode'] == 'continue'
st, = api.(admin, :post, 'cases/types', { name: 'Invasor', default_assignee_id: User.create!(name: 'X', email: "x-#{SecureRandom.hex(3)}@x.test", password: 'Senha-forte-1!').id })
ok 'responsável padrão de fora da conta: 404', st == 404

# Abrir
st, c1 = api.(admin, :post, 'cases', { title: 'Pedido trocado', type_id: troca['id'], conversation_id: conv1.display_id })
ok 'abrir pela conversa: 200, contato da conversa, padrões do tipo', st == 200 && c1.dig('contact', 'id') == maria.id &&
                                                                     c1['priority'] == 'high' && c1.dig('assignee', 'id') == agente.id && c1['source'] == 'conversation'
ok 'número CAS-ano-0001', c1['number'] == "CAS-#{Time.current.year}-0001"
ok 'prazo = agora + 10 h', (c1['due_at'] - 10.hours.from_now.to_i).abs < 60
_, c1 = api.(admin, :get, "cases/#{c1['id']}")
ok 'conversa de origem ligada e evento created', c1['conversations'].map { |c| [c['id'], c['origin']] } == [[conv1.display_id, true]] &&
                                                c1['events'].map { |e| e['kind'] } == ['created']
nota = conv1.messages.where(private: true).last
ok 'responsável mencionado numa nota da conversa', nota&.content.to_s.include?("mention://user/#{agente.id}/") && nota.content.include?(c1['number'])
ok 'faltam os obrigatórios', c1['missing_required_fields'] == ['pedido']

duda = tipos['payload'].first
st, c2 = api.(agente, :post, 'cases', { title: 'Pergunta', type_id: duda['id'], contact_id: joao.id })
ok 'abrir manual pelo contato: CAS-0002, sem nota a ninguém', st == 200 && c2['number'].end_with?('-0002') && c2['source'] == 'manual' &&
                                                           c2['assignee'].nil? && conv2.messages.none?
st, = api.(admin, :post, 'cases', { title: 'Sem contato', type_id: duda['id'] })
ok 'sem contato: 422', st == 422
st, = api.(admin, :post, 'cases', { title: 'Sem tipo', contact_id: joao.id })
ok 'sem tipo: 422', st == 422
st, = api.(admin, :post, 'cases', { title: 'Invasor', type_id: duda['id'], contact_id: de_fora.id })
ok 'contato de outra conta: 404', st == 404
st, = api.(admin, :post, 'cases', { title: 'Misturado', type_id: duda['id'], contact_id: joao.id, conversation_id: conv1.display_id })
ok 'conversa de outro contato: 404', st == 404

# Prefixo
st, = api.(agente, :patch, 'cases/settings', { prefix: 'SUP' })
ok 'agente não muda o prefixo: 401', st == 401
st, = api.(admin, :patch, 'cases/settings', { prefix: 'su p!' })
ok 'prefixo inválido: 422', st == 422
st, pref = api.(admin, :patch, 'cases/settings', { prefix: 'sup' })
_, c3 = api.(admin, :post, 'cases', { title: 'Com prefixo novo', type_id: duda['id'], contact_id: joao.id })
ok 'prefixo em maiúsculas e no número seguinte', st == 200 && pref['prefix'] == 'SUP' && c3['number'] == "SUP-#{Time.current.year}-0003"

# Campos e edição
st, = api.(agente, :patch, "cases/#{c1['id']}", { field_values: { valor: 'cem' } })
ok 'número com texto: 422', st == 422
st, = api.(agente, :patch, "cases/#{c1['id']}", { field_values: { motivo: 'Outro' } })
ok 'opção fora da lista: 422', st == 422
st, = api.(agente, :patch, "cases/#{c1['id']}", { field_values: { inexistente: 'x' } })
ok 'campo que o tipo não tem: 422', st == 422
st, = api.(agente, :patch, "cases/#{c1['id']}", { field_values: { entrega: '2026-02-30' } })
ok 'data inválida: 422', st == 422
st, c1 = api.(agente, :patch, "cases/#{c1['id']}", { field_values: { valor: 120.5, motivo: 'Defeito', urgente: false }, priority: 'urgent', assignee_id: admin.id })
ok 'campos válidos, prioridade e responsável', st == 200 && c1['field_values'] == { 'valor' => 120.5, 'motivo' => 'Defeito', 'urgente' => false } &&
                                                c1['priority'] == 'urgent' && c1.dig('assignee', 'id') == admin.id
_, c1 = api.(agente, :patch, "cases/#{c1['id']}", { field_values: { entrega: '2026-11-02' } })
ok 'editar um campo mantém os outros', c1['field_values'].keys.sort == %w[entrega motivo urgente valor]
kinds = c1['events'].map { |e| e['kind'] }
ok 'histórico: campos, prioridade e responsável', kinds.count('field_changed') == 2 && kinds.include?('priority_changed') && kinds.include?('assigned')
ok 'quem recebeu de outro é mencionado', conv1.messages.where(private: true).last.content.include?("mention://user/#{admin.id}/")

# Situações e prazo
st, = api.(agente, :post, "cases/#{c1['id']}/resolve", { outcome: 'solved' })
ok 'resolver sem o obrigatório: 422', st == 422
_, c1 = api.(agente, :post, "cases/#{c1['id']}/start")
ok 'começar: em andamento', c1['status'] == 'in_progress'
due = c1['due_at']
_, c1 = api.(agente, :post, "cases/#{c1['id']}/wait_customer")
ok 'esperando o cliente pausa o prazo', c1['status'] == 'waiting_customer' && c1['paused_at'].present?
Cases::Case.find(c1['id']).update!(paused_at: 3.hours.ago)
_, c1 = api.(agente, :post, "cases/#{c1['id']}/start")
ok 'ao voltar, o prazo anda o tempo parado (3 h)', c1['paused_at'].nil? && (c1['due_at'] - due - 3.hours.to_i).abs < 60
st, = api.(agente, :post, "cases/#{c1['id']}/reopen")
ok 'reabrir caso ativo: 422', st == 422
api.(agente, :patch, "cases/#{c1['id']}", { field_values: { pedido: 'A-123' } })
st, c1 = api.(agente, :post, "cases/#{c1['id']}/resolve", { outcome: 'duplicate', resolution: 'Era o mesmo do pedido A-100' })
ok 'resolver com desfecho e texto', st == 200 && c1['status'] == 'resolved' && c1['outcome'] == 'duplicate' && Cases::Case.find(c1['id']).resolved_by_id == agente.id
st, = api.(agente, :post, "cases/#{c1['id']}/resolve")
ok 'resolver de novo: 422', st == 422
_, c1 = api.(agente, :post, "cases/#{c1['id']}/reopen")
ok 'reabrir limpa desfecho e quem resolveu', c1['status'] == 'in_progress' && c1['outcome'].nil? && Cases::Case.find(c1['id']).resolved_by_id.nil?
_, c1 = api.(agente, :post, "cases/#{c1['id']}/note", { body: 'Liguei para a transportadora' })
nota_ev = c1['events'].last
ok 'nota no histórico com o autor', nota_ev['kind'] == 'note' && nota_ev['actor_name'] == agente.available_name
st, = api.(agente, :post, "cases/#{c1['id']}/note", { body: '' })
ok 'nota vazia: 4xx', st >= 400
conv1b = conversa.(maria)
_, c1 = api.(agente, :post, "cases/#{c1['id']}/link_conversation", { conversation_id: conv1b.display_id })
ok 'ligar outra conversa do mesmo contato', c1['conversations'].size == 2
st, = api.(agente, :post, "cases/#{c1['id']}/link_conversation", { conversation_id: conv2.display_id })
ok 'ligar conversa de outro contato: 404', st == 404
st, = api.(agente, :post, "cases/#{c2['id']}/cancel", { resolution: 'Duplicado' })
ok 'cancelar', st == 200 && Cases::Case.find(c2['id']).canceled?

# Filtros e atrasados
Cases::Case.find(c3['id']).update!(due_at: 2.hours.ago)
_, ativos = api.(admin, :get, 'cases')
ok 'ativos: o atrasado primeiro, cancelado fora', ativos['payload'].map { |c| c['id'] } == [c3['id'], c1['id']] && ativos['payload'].first['overdue']
_, cancelados = api.(admin, :get, 'cases?status=canceled')
ok 'cancelados', cancelados['payload'].map { |c| c['id'] } == [c2['id']]
_, meus = api.(admin, :get, 'cases?assignee_id=me')
ok 'meus', meus['payload'].map { |c| c['id'] } == [c1['id']]
_, sem_dono = api.(admin, :get, 'cases?assignee_id=none')
ok 'sem responsável', sem_dono['payload'].map { |c| c['id'] } == [c3['id']]
_, busca = api.(admin, :get, 'cases?q=maria')
ok 'busca sem acento pelo contato', busca['payload'].map { |c| c['id'] } == [c1['id']]
_, busca = api.(admin, :get, "cases?q=SUP-#{Time.current.year}")
ok 'busca pelo número', busca['payload'].map { |c| c['id'] } == [c3['id']]
_, da_conversa = api.(admin, :get, "cases?conversation_id=#{conv1b.display_id}&status=all")
ok 'casos de uma conversa', da_conversa['payload'].map { |c| c['id'] } == [c1['id']]
_, atrasados = api.(admin, :get, 'cases?overdue=true')
ok 'só atrasados', atrasados['payload'].map { |c| c['id'] } == [c3['id']]
st, = api.(admin, :get, 'cases?status=xyz')
ok 'situação inválida: 400', st == 400
_, conta = api.(agente, :get, 'cases/overdue_count')
ok 'número vermelho: 1 na conta, 0 meu', conta == { 'count' => 1, 'mine' => 0 }
Cases::Case.find(c1['id']).update!(due_at: 1.hour.ago, paused_at: Time.current)
ok 'esperando o cliente não conta como atrasado', account.cases.overdue.pluck(:id) == [c3['id']]
account.enable_features!('sales_pipeline')
st, radar = api.(admin, :get, 'sales/radar')
ok 'Radar traz os casos vencidos', st == 200 && radar['overdue_cases'].map { |c| c['id'] } == [c3['id']]

# Tipos com casos, juntar e apagar contato
st, = api.(admin, :delete, "cases/types/#{troca['id']}")
ok 'tipo com caso não se apaga: 422', st == 422
st, = api.(admin, :patch, "cases/types/#{troca['id']}", { active: false })
ok 'desativar', st == 200 && !account.cases_types.find(troca['id']).active
st, = api.(agente, :delete, "cases/#{c3['id']}")
ok 'agente não apaga caso: 401', st == 401

ContactMergeAction.new(account: account, base_contact: joao, mergee_contact: maria).perform
ok 'juntar contatos leva os casos', account.cases.where(contact_id: joao.id).count == 3
evs = Cases::Event.where(case_id: c1['id']).count
joao.reload.destroy!
ok 'apagar o contato apaga casos, histórico e ligações', account.cases.none? && evs.positive? &&
                                                          Cases::Event.where(case_id: c1['id']).none? && Cases::CaseConversation.where(case_id: c1['id']).none?

account.disable_features!('cases')
ok 'sem a flag: 401', api.(admin, :get, 'cases').first == 401
ok 'Radar sem a flag não traz casos', api.(admin, :get, 'sales/radar').last['overdue_cases'] == []
