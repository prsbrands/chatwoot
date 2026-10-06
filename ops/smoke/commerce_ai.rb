# Comercial, fase 4a: o que o bot do n8n usa para vender com o catálogo
# (Commerce::BotController e Commerce::AiSales) contra Postgres e Redis
# descartáveis: os itens disponíveis com preço, o rascunho de cotização com
# nota e menção à equipe, e a assinatura do plano com o link.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Loja', locale: 'es')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
bot = User.create!(name: 'Bot', email: "bot-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: bot, role: :agent)
inbox = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/hook'))
contact = account.contacts.create!(name: 'María Pérez', email: 'maria@cliente.test', additional_attributes: { 'billing_tax_id' => '8-1-2' })
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversa = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
deal = Sales::Deal.open_for_contact!(contact, conversation: conversa)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil, user: bot|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

categoria = account.commerce_categories.create!(name: 'Cortinas')
cortina = account.commerce_items.create!(name: 'Cortina roller', price: 35.5, currency: 'USD', unit: 'm2', category: categoria,
                                         description: "Tela blackout\nmedida a gusto")
projeto = account.commerce_items.create!(name: 'Proyecto a medida', kind: :service)
account.commerce_items.create!(name: 'Agotado', price: 10, available: false)
plano = account.commerce_items.create!(name: 'Plan Pro', price: 49.9, currency: 'USD', billing_interval: :month, kind: :service)
plano_brl = account.commerce_items.create!(name: 'Plano BR', price: 99, currency: 'BRL', billing_interval: :year, kind: :service)
provider = account.commerce_payment_providers.new(provider: :stripe, environment: :sandbox, credentials: { secret_key: 'sk_test_x' }.to_json)
provider.save!
cartao = account.commerce_payment_methods.create!(name: 'Tarjeta', kind: :card, provider: provider)

# --- catálogo -------------------------------------------------------------------
st, catalogo = api.(:get, "bot/catalog?conversation_id=#{conversa.display_id}")
itens = catalogo['items'].index_by { |item| item['name'] }
ok 'catalogo so com os disponiveis', st == 200 && itens.keys.sort == ['Cortina roller', 'Plan Pro', 'Plano BR', 'Proyecto a medida'].sort
ok 'item com preco, unidade e categoria', itens['Cortina roller'].slice('price', 'currency', 'unit', 'category', 'billing_interval') ==
                                         { 'price' => '35.5', 'currency' => 'USD', 'unit' => 'm2', 'category' => 'Cortinas', 'billing_interval' => 'one_time' }
ok 'sob orcamento sem preco', itens['Proyecto a medida']['price'].nil?
ok 'plano em USD assinavel pelo Stripe; o em BRL tambem (Stripe cobra BRL)', itens['Plan Pro']['subscribable'] && itens['Plano BR']['subscribable'] &&
                                                                             !itens['Cortina roller']['subscribable']
cartao.update!(active: false)
_, sem_forma = api.(:get, 'bot/catalog')
ok 'sem forma online ativa, nenhum plano assinavel', sem_forma['items'].none? { |item| item['subscribable'] }
cartao.update!(active: true)
ok 'sem a flag commerce: 401', account.disable_features!('commerce').then { api.(:get, 'bot/catalog').first == 401 }
account.enable_features!('commerce')

# --- rascunho de cotização --------------------------------------------------------
st, cotizacao = api.(:post, 'bot/quotes', { conversation_id: conversa.display_id, language: 'es',
                                             lines: [{ item_id: cortina.id, quantity: '2.5' }, { item_id: projeto.id }] })
doc = Commerce::Document.find_by(id: cotizacao&.dig('id'))
ok 'rascunho criado com os itens e precos do catalogo', st == 200 && doc.quote? && doc.draft? && doc.items.size == 2 &&
                                                     doc.items.first.unit_price == BigDecimal('35.5') && doc.items.first.quantity == BigDecimal('2.5') &&
                                                     doc.items.first.unit == 'm2' && doc.items.last.unit_price.nil? && doc.total == BigDecimal('88.75')
ok 'cliente, conversa e negocio da conversa', doc.contact == contact && doc.conversation == conversa && doc.deal == deal &&
                                              doc.customer['tax_id'] == '8-1-2' && doc.language == 'es' && doc.payment_method_ids == [cartao.id]
nota = conversa.messages.where(private: true).last
ok 'nota interna menciona o admin com o numero e o link', nota.content.include?("mention://user/#{ana.id}/") && nota.content.include?(doc.number) &&
                                                         nota.content.include?("/documents/#{doc.id}")
ok 'rascunho marcado como da IA e contado para revisao', doc.prepared_by_ai? && api.(:get, 'documents/review_count', user: ana)[1] == { 'count' => 1 } &&
                                                       api.(:get, "documents/#{doc.id}", user: ana)[1]['prepared_by_ai'] == true
deal.update!(assignee: bot)
_, de_novo = api.(:post, 'bot/quotes', { conversation_id: conversa.display_id, lines: [{ item_id: cortina.id, quantity: 10 }] })
ok 'cliente muda a quantidade: o mesmo rascunho e atualizado', de_novo['id'] == doc.id && doc.reload.items.size == 1 &&
                                                              doc.items.first.quantity == 10 && account.commerce_documents.count == 1
ok 'com responsavel no negocio, a mencao e dele, avisando a mudanca',
   conversa.messages.where(private: true).last.content.include?("mention://user/#{bot.id}/") &&
   conversa.messages.where(private: true).last.content.include?('changed the request')
Commerce::DocumentFlow.new(doc).mark_sent!
ok 'enviado, sai da revisao', api.(:get, 'documents/review_count')[1]['count'].zero?
api.(:post, 'bot/quotes', { conversation_id: conversa.display_id, lines: [{ item_id: cortina.id, quantity: 1 }] })
ok 'depois de enviado, um pedido novo vira outro rascunho', account.commerce_documents.count == 2 &&
                                                          api.(:get, 'documents/review_count')[1]['count'] == 1
agotado = account.commerce_items.find_by(name: 'Agotado')
ok 'item indisponivel: 404, nada criado', api.(:post, 'bot/quotes', { conversation_id: conversa.display_id, lines: [{ item_id: agotado.id }] }).first == 404 &&
                                          account.commerce_documents.count == 2 && account.commerce_documents.order(:id).last.items.first.quantity == 1
ok 'conversa de outra conta: 404', api.(:post, 'bot/quotes', { conversation_id: 999_999, lines: [{ item_id: cortina.id }] }).first == 404

# --- assinatura -----------------------------------------------------------------
st, assinatura = api.(:post, 'bot/subscriptions', { conversation_id: conversa.display_id, item_id: plano.id, language: 'pt' })
sub = Commerce::Subscription.find_by(id: assinatura&.dig('id'))
ok 'assinatura criada com a forma que cobra o plano', st == 200 && sub.pending? && sub.payment_method == cartao && sub.conversation == conversa &&
                                                     sub.language == 'pt' && assinatura['public_url'] == sub.public_url
_, de_novo = api.(:post, 'bot/subscriptions', { conversation_id: conversa.display_id, item_id: plano.id })
ok 'pedir de novo devolve o mesmo link', de_novo['id'] == sub.id && account.commerce_subscriptions.count == 1
ok 'item avulso nao vira assinatura: 404', api.(:post, 'bot/subscriptions', { conversation_id: conversa.display_id, item_id: cortina.id }).first == 404
