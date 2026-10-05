# Comercial, fase 2 (orçamentos e faturas) contra Postgres/Redis descartáveis.
# E-mail em :test (nada sai do container) e CSRF desligado para o POST da página
# pública, como faz um teste de request.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
ActionController::Base.allow_forgery_protection = false

account = Account.create!(name: 'Loja', locale: 'es')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
beto = User.create!(name: 'Beto', email: "beto-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: beto, role: :agent)
inbox = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/hook'))
voz = account.inboxes.create!(name: 'Voz', channel: Channel::Api.create!(account: account))
contact = account.contacts.create!(name: 'María Pérez', email: 'maria@cliente.test')
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversa = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
deal = Sales::Deal.open_for_contact!(contact, conversation: conversa)
cortina = account.commerce_items.create!(name: 'Cortina blackout', price: 100, currency: 'USD', unit: 'm2')
account.commerce_payment_methods.create!(name: 'Yappy', kind: :yappy, instructions: 'Yappy al 6000-0000')
yappy = account.commerce_payment_methods.first

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil, user: ana|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

linhas = [
  { item_id: cortina.id, name: 'Cortina blackout', quantity: '2.5', unit: 'm2', unit_price: '100', discount_percent: '10', tax_rate: '7' },
  { name: 'Instalación', quantity: '1', unit: 'service', unit_price: '50', tax_rate: '7' },
  { name: 'Riel a medida', quantity: '1', unit: 'project', unit_price: '' }
]
st, cot = api.(:post, 'documents', { kind: 'quote', contact_id: contact.id, deal_id: deal.id, conversation_id: conversa.id,
                                     customer: { name: 'María Pérez', tax_id_label: 'RUC', tax_id: '8-123-456', address: 'Calle 50' },
                                     items: linhas, tax_mode: 'exclusive', language: 'es', due_date: (Date.current + 15).to_s })
# 2,5 × 100 = 250 − 10% = 225 + 7% = 15,75; 50 + 3,50; riel sem preço = 0.
ok 'orcamento: numero COT-ano-0001', st == 200 && cot['number'] == "COT-#{Date.current.year}-0001" && cot['status'] == 'draft'
ok 'imposto por fora: totais', cot['subtotal'] == '300.0' && cot['discount_total'] == '25.0' && cot['tax_total'] == '19.25' &&
                               cot['total'] == '294.25'
ok 'linha sob orcamento fica sem preco', cot['items'][2]['unit_price'].nil? && cot['items'][2]['line_total'] == '0.0'
ok 'dados fiscais lembrados no contato', contact.reload.additional_attributes['billing_tax_id'] == '8-123-456'

_, incl = api.(:patch, "documents/#{cot['id']}", { tax_mode: 'inclusive', items: [{ name: 'Servicio', quantity: '1', unit: 'service', unit_price: '107', tax_rate: '7' }] })
ok 'imposto incluso: total = preco, imposto destacado', incl['total'] == '107.0' && incl['tax_total'] == '7.0'
_, isento = api.(:patch, "documents/#{cot['id']}", { tax_mode: 'exempt' })
ok 'isento: sem imposto', isento['total'] == '107.0' && isento['tax_total'] == '0.0'
_, cot = api.(:patch, "documents/#{cot['id']}", { tax_mode: 'exclusive', items: linhas })

_, outro = api.(:post, 'documents', { kind: 'quote', items: [] }, user: beto)
ok 'agente cria; numero seguinte', outro['number'] == "COT-#{Date.current.year}-0002"

s.get "/d/#{cot['public_token'] || cot['public_url'].split('/').last}"
ok 'rascunho nao aparece no link publico', s.response.status == 404

st, com_pdf = api.(:post, "documents/#{cot['id']}/pdf")
pdf = Commerce::Document.find(cot['id']).latest_pdf
ok 'PDF gerado e arquivado', st == 200 && com_pdf['pdfs'].size == 1 && pdf.download.start_with?('%PDF')
api.(:post, "documents/#{cot['id']}/pdf")
ok 'cada geracao fica no arquivo', Commerce::Document.find(cot['id']).pdfs.count == 2

st, enviado = api.(:post, "documents/#{cot['id']}/deliver", { channel: 'conversation', conversation_id: conversa.display_id })
msg = conversa.messages.outgoing.last
ok 'enviado pela conversa: PDF anexo e link', st == 200 && enviado['status'] == 'sent' && msg.attachments.count == 1 &&
                                               msg.content.include?('/d/')
ci_voz = ContactInbox.create!(contact: contact, inbox: voz, source_id: SecureRandom.uuid)
conversa_voz = Conversation.create!(account: account, inbox: voz, contact: contact, contact_inbox: ci_voz)
ok 'caixa sem webhook (voz) recusa o envio: 422',
   api.(:post, "documents/#{cot['id']}/deliver", { channel: 'conversation', conversation_id: conversa_voz.display_id }).first == 422
direto = msg.webhook_data[:attachments].first[:data_url]
ok 'webhook leva o endereco direto do PDF, sem redirecionar', direto.include?('/rails/active_storage/disk/') && !direto.include?('redirect')
st, = api.(:post, "documents/#{cot['id']}/deliver", { channel: 'email', to: 'maria@cliente.test' })
mail = ActionMailer::Base.deliveries.last
html = mail.html_part&.body.to_s
ok 'enviado por e-mail com o PDF', st == 200 && mail.to == ['maria@cliente.test'] && mail.subject.start_with?('Cotización') &&
                                   mail.attachments.map(&:filename).include?("COT-#{Date.current.year}-0001.pdf")
ok 'e-mail em HTML com o botao para o link e o total', html.include?('Ver cotización') && html.include?('/d/') && html.include?('294,25') &&
                                                      mail.text_part&.body.to_s.include?('/d/')

link = enviado['public_url'].sub(%r{\Ahttps?://[^/]+}, '')
s.get link
ok 'pagina publica em espanhol, com aceitar', s.response.status == 200 && s.response.body.include?('Aceptar cotización') &&
                                              s.response.body.include?('Yappy al 6000-0000')
s.get "#{link}/pdf"
ok 'PDF pelo link publico', s.response.status == 200 && s.response.media_type == 'application/pdf'
s.post "#{link}/accept"
ok 'cliente aceita pelo link', Commerce::Document.find(cot['id']).accepted?
ok 'aceito nao edita mais: 422', api.(:patch, "documents/#{cot['id']}", { notes: 'x' }).first == 422

st, fat = api.(:post, "documents/#{cot['id']}/to_invoice")
ok 'fatura gerada do orcamento', st == 200 && fat['number'] == "FAT-#{Date.current.year}-0001" && fat['kind'] == 'invoice' &&
                                 fat['total'] == '294.25' && fat['items'].size == 3 && fat['source_document_id'] == cot['id']
ok 'pagamento em rascunho: 422', api.(:post, "documents/#{fat['id']}/payments", { amount: '10', paid_on: Date.current.to_s }).first == 422
api.(:post, "documents/#{fat['id']}/deliver", { channel: 'email', to: 'maria@cliente.test' })
ok 'agente nao registra pagamento: 401',
   api.(:post, "documents/#{fat['id']}/payments", { amount: '10', paid_on: Date.current.to_s }, user: beto).first == 401
_, parcial = api.(:post, "documents/#{fat['id']}/payments", { amount: '100', paid_on: Date.current.to_s, payment_method_id: yappy.id })
ok 'pagamento parcial', parcial['status'] == 'partially_paid' && parcial['amount_paid'] == '100.0' && parcial['balance'] == '194.25'
_, paga = api.(:post, "documents/#{fat['id']}/payments", { amount: '194.25', paid_on: Date.current.to_s })
ok 'fatura paga', paga['status'] == 'paid' && paga['balance'] == '0.0'
deal.reload
ok 'negocio ganho com o valor da fatura', deal.won? && deal.value_cents == 29_425 && deal.currency == 'USD'
ok 'anular com pagamento: 422', api.(:post, "documents/#{fat['id']}/void").first == 422
_, devolvida = api.(:delete, "documents/#{fat['id']}/payments/#{paga['payments'].last['id']}")
ok 'remover pagamento volta a parcial', devolvida['status'] == 'partially_paid'

ok 'agente nao anula: 401', api.(:post, "documents/#{outro['id']}/void", nil, user: beto).first == 401
ok 'apagar rascunho', api.(:delete, "documents/#{outro['id']}").first == 200
_, lista = api.(:get, "documents?kind=quote&q=maria")
ok 'lista com busca pelo cliente', lista['payload'].map { |d| d['id'] } == [cot['id']]

ok 'fatura com pagamento nao reabre: 422', api.(:post, "documents/#{fat['id']}/reopen").first == 422
_, reaberto = api.(:post, "documents/#{cot['id']}/reopen")
ok 'orcamento aceito reabre como rascunho editavel', reaberto['status'] == 'draft' && reaberto['editable'] &&
                                                     api.(:patch, "documents/#{cot['id']}", { notes: 'revisado' }).first == 200
api.(:post, "documents/#{cot['id']}/archive")
ok 'arquivado sai da lista principal', api.(:get, 'documents?kind=quote')[1]['payload'].none? { |d| d['id'] == cot['id'] }
ok 'e aparece em Arquivados', api.(:get, 'documents?kind=quote&archived=true')[1]['payload'].map { |d| d['id'] } == [cot['id']]
api.(:post, "documents/#{cot['id']}/unarchive")
ok 'desarquivado volta para a lista', api.(:get, 'documents?kind=quote')[1]['payload'].any? { |d| d['id'] == cot['id'] }

account.commerce_profile.update!(quote_prefix: 'PRE')
_, ingles = api.(:post, 'documents', { kind: 'quote', language: 'en', items: [{ name: 'Café ☕ e acentuação', quantity: '1', unit: 'unit', unit_price: '9.9' }] })
api.(:post, "documents/#{ingles['id']}/pdf")
ok 'prefixo da empresa e PDF com caractere fora do Windows-1252', ingles['number'].start_with?('PRE-') &&
                                                                  Commerce::Document.find(ingles['id']).latest_pdf.download.start_with?('%PDF')
