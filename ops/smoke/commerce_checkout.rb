# Comercial, fase 3a (cobrança online pelo Stripe e recibos) contra Postgres e
# Redis descartáveis. O Stripe entra falso (class_eval no client), mas a
# assinatura do webhook é a de verdade: Stripe::Webhook::Signature. O recibo
# (Commerce::ReceiptJob) roda na hora; os outros jobs ficam só enfileirados.
# E-mail em :test.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
jobs = ActiveJob::QueueAdapters::TestAdapter.new
jobs.perform_enqueued_jobs = true
jobs.filter = [Commerce::ReceiptJob]
ActiveJob::Base.queue_adapter = jobs

module FakeStripe
  SESSIONS = {}
  ENDPOINTS = {}

  def self.session(id, **attrs)
    SESSIONS[id] = Stripe::StripeObject.construct_from(SESSIONS.fetch(id).to_hash.merge(attrs))
  end

  module Sessions
    def self.create(params, _opts = {})
      id = "cs_test_#{SecureRandom.hex(4)}"
      SESSIONS[id] = Stripe::StripeObject.construct_from(
        id: id, url: "https://checkout.stripe.test/#{id}", status: 'open', payment_status: 'unpaid', payment_intent: nil,
        amount_total: params[:line_items][0][:price_data][:unit_amount], sent: params
      )
    end

    def self.retrieve(id) = SESSIONS.fetch(id)
  end

  module Endpoints
    def self.create(params)
      id = "we_#{SecureRandom.hex(4)}"
      ENDPOINTS[id] = params
      Stripe::StripeObject.construct_from(id: id, secret: "whsec_#{SecureRandom.hex(8)}")
    end

    def self.delete(id) = ENDPOINTS.delete(id)
  end

  module Client
    def self.v1 = self
    def self.checkout = self
    def self.sessions = Sessions
    def self.webhook_endpoints = Endpoints
  end
end

Commerce::Gateways::Stripe.class_eval do
  private

  def client = FakeStripe::Client
end

account = Account.create!(name: 'Loja', locale: 'es')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
beto = User.create!(name: 'Beto', email: "beto-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: beto, role: :agent)
inbox = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/hook'))
contact = account.contacts.create!(name: 'María Pérez', email: 'maria@cliente.test')
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversa = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
deal = Sales::Deal.open_for_contact!(contact, conversation: conversa)
transferencia = account.commerce_payment_methods.create!(name: 'Transferencia', kind: :bank_transfer, instructions: 'Banco General 04-00-00')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil, user: ana|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end
nova_fatura = lambda do |preco|
  _, fatura = api.(:post, 'documents', { kind: 'invoice', contact_id: contact.id, deal_id: deal.id, language: 'es', tax_mode: 'exempt',
                                         customer: { name: 'María Pérez', email: 'maria@cliente.test' },
                                         items: [{ name: 'Cortina', quantity: '1', unit: 'unit', unit_price: preco.to_s }] })
  api.(:post, "documents/#{fatura['id']}/deliver", { channel: 'conversation', conversation_id: conversa.display_id })
  api.(:post, "documents/#{fatura['id']}/deliver", { channel: 'email', to: 'maria@cliente.test' })[1]
end
caminho = ->(doc) { doc['public_url'].sub(%r{\Ahttps?://[^/]+}, '') }
pagina = ->(doc) { URI(Commerce::DocumentFlow.new(doc).public_url).path }

# --- provedor ---------------------------------------------------------------
ok 'agente nao ve provedores: 401', api.(:get, 'payment_providers', user: beto).first == 401
st, = api.(:post, 'payment_providers', { provider: 'stripe', environment: 'sandbox', credentials: { secret_key: 'sk_live_errada' } })
ok 'chave live no ambiente de teste: 422', st == 422 && account.commerce_payment_providers.none?
ok 'Mercado Pago ainda nao: 422', api.(:post, 'payment_providers', { provider: 'mercado_pago', credentials: { secret_key: 'x' } }).first == 422
st, prov = api.(:post, 'payment_providers', { provider: 'stripe', environment: 'sandbox', credentials: { secret_key: 'sk_test_abc123wxyz' } })
provider = Commerce::PaymentProvider.find_by(id: prov&.dig('id'))
ok 'Stripe conectado: webhook criado na conta Stripe', st == 200 && prov['credential_hint'] == '…wxyz' &&
                                                       FakeStripe::ENDPOINTS.values.last[:url] == provider.webhook_url &&
                                                       provider.webhook_secret.start_with?('whsec_')
cru = ActiveRecord::Base.connection.select_value("SELECT credentials || webhook_secret FROM commerce_payment_providers WHERE id = #{provider.id}")
ok 'chave e segredo cifrados no banco', !cru.include?('sk_test') && !cru.include?('whsec_')
_, cartao = api.(:post, 'payment_methods', { name: 'Tarjeta', kind: 'card', provider_id: provider.id })
ok 'forma de pagamento online', cartao['provider_id'] == provider.id && Commerce::PaymentMethod.find(cartao['id']).online?

# --- pagar uma parte ----------------------------------------------------------
fatura = nova_fatura.(300)
link = caminho.(fatura)
s.get link
ok 'pagina da fatura: botao Pagar e instrucoes so das formas offline',
   s.response.body.include?('Pagar con Tarjeta') && s.response.body.include?('Banco General') && s.response.body.include?('id="pay"')
s.post "#{link}/pay", params: { amount: '300.01', payment_method_id: cartao['id'] }
ok 'acima do saldo: 422, nada criado', s.response.status == 422 && s.response.body.include?('No pudimos iniciar') && Commerce::Checkout.none?
s.post "#{link}/pay", params: { amount: '0.50', payment_method_id: cartao['id'] }
ok 'abaixo do minimo: 422', s.response.status == 422
s.post "#{link}/pay", params: { amount: '100', payment_method_id: transferencia.id }
ok 'forma offline nao paga online: 422', s.response.status == 422
s.post "#{link}/pay", params: { amount: '100', payment_method_id: cartao['id'] }
checkout = Commerce::Checkout.last
enviado = FakeStripe::SESSIONS[checkout&.external_id]&.sent
ok 'parcial: vai para o Stripe com o valor do servidor', s.response.status == 302 && s.response.location.start_with?('https://checkout.stripe.test/') &&
                                                       checkout.pending? && enviado[:line_items][0][:price_data][:unit_amount] == 10_000 &&
                                                       enviado[:locale] == 'es' && enviado[:success_url].end_with?("?checkout=#{checkout.id}")

evento = lambda do |sessao, tipo = 'checkout.session.completed'|
  { id: "evt_#{SecureRandom.hex(4)}", object: 'event', type: tipo,
    data: { object: sessao.to_hash.except(:sent).merge(object: 'checkout.session') } }.to_json
end
webhook = lambda do |payload, secret: provider.webhook_secret, token: provider.webhook_token|
  agora = Time.now
  assinatura = Stripe::Webhook::Signature.generate_header(agora, Stripe::Webhook::Signature.compute_signature(agora, payload, secret))
  s.post "/commerce/webhooks/stripe/#{token}", params: payload, headers: { 'Content-Type' => 'application/json', 'Stripe-Signature' => assinatura }
  s.response.status
end

pago = FakeStripe.session(checkout.external_id, status: 'complete', payment_status: 'paid', payment_intent: 'pi_1')
ok 'webhook com assinatura errada: 400, nada pago', webhook.(evento.(pago), secret: 'whsec_falso') == 400 && checkout.reload.pending?
ok 'webhook de token desconhecido: 404', webhook.(evento.(pago), token: 'nao-existe') == 404
emails_antes = ActionMailer::Base.deliveries.size
ok 'webhook valido: 200', webhook.(evento.(pago)) == 200
fat = Commerce::Document.find(fatura['id'])
pagamento = fat.payments.last
recibo = pagamento&.receipt
ok 'fatura parcial com o pagamento online', fat.partially_paid? && fat.amount_paid == 100 && checkout.reload.paid? && pagamento.online?
ok 'recibo REC-ano-0001 com a posicao da fatura', recibo&.number == "REC-#{Date.current.year}-0001" && recibo.total == 100 &&
                                                  recibo.details['paid_to_date'] == '100.0' && recibo.details['balance'] == '200.0'
mail = ActionMailer::Base.deliveries.last
ok 'recibo enviado pelo e-mail da fatura', ActionMailer::Base.deliveries.size == emails_antes + 1 && mail.to == ['maria@cliente.test'] &&
                                           mail.subject.start_with?('Recibo') && recibo.reload.sent?
ok 'recibo enviado pela conversa da fatura, com nota interna',
   conversa.messages.where(private: false).last.content.include?(recibo.number) &&
   conversa.messages.where(private: true).last.content.include?('Online payment received')
webhook.(evento.(pago))
ok 'aviso repetido nao paga duas vezes', fat.payments.count == 1 && Commerce::Document.receipt.count == 1

s.get pagina.(recibo)
ok 'pagina publica do recibo', s.response.status == 200 && s.response.body.include?('Recibimos la suma') && s.response.body.exclude?('id="pay"')
ok 'PDF do recibo', Commerce::DocumentFlow.new(recibo).archive_pdf!.download.start_with?('%PDF')
ok 'pagamento online nao se apaga pela tela: 422', api.(:delete, "documents/#{fat.id}/payments/#{pagamento.id}").first == 422

# --- volta do cliente sem esperar o webhook ---------------------------------
s.post "#{link}/pay", params: { amount: '200', payment_method_id: cartao['id'] }
volta = Commerce::Checkout.last
FakeStripe.session(volta.external_id, status: 'complete', payment_status: 'paid')
s.get "#{link}?checkout=#{volta.id}"
ok 'na volta, pergunta ao Stripe e confirma', s.response.body.include?('Pago recibido') && fat.reload.paid? && deal.reload.won?
s.post "#{link}/pay", params: { amount: '1', payment_method_id: cartao['id'] }
ok 'fatura paga nao abre pagamento', s.response.status == 422 && Commerce::Checkout.count == 2

# --- conciliação ----------------------------------------------------------------
segunda = nova_fatura.(50)
s.post "#{caminho.(segunda)}/pay", params: { amount: '50', payment_method_id: cartao['id'] }
perdido = Commerce::Checkout.last
FakeStripe.session(perdido.external_id, status: 'complete', payment_status: 'paid')
s.post "#{caminho.(segunda)}/pay", params: { amount: '10', payment_method_id: cartao['id'] }
abandonado = Commerce::Checkout.last
perdido.update_column(:created_at, 5.minutes.ago) # rubocop:disable Rails/SkipsModelValidations
abandonado.update_column(:created_at, 25.hours.ago) # rubocop:disable Rails/SkipsModelValidations
Commerce::CheckoutReconcileJob.perform_now
ok 'conciliacao paga o webhook perdido', perdido.reload.paid? && Commerce::Document.find(segunda['id']).paid?
ok 'conciliacao expira a tentativa abandonada', abandonado.reload.expired?

# --- pagamento à mão com recibo ------------------------------------------------
terceira = nova_fatura.(80)
st, com_recibo = api.(:post, "documents/#{terceira['id']}/payments", { amount: '30', paid_on: Date.current.to_s,
                                                                         payment_method_id: transferencia.id, send_receipt: true })
manual = com_recibo['payments'].last
ok 'pagamento a mao com recibo', st == 200 && manual['receipt_number'].present? && !manual['online']
recibo_manual = Commerce::Document.find(manual['receipt_id'])
ok 'recibo manual enviado', recibo_manual.sent? && recibo_manual.details['method'] == 'Transferencia'
_, sem_recibo = api.(:post, "documents/#{terceira['id']}/payments", { amount: '10', paid_on: Date.current.to_s })
ok 'sem enviar recibo: nenhum', sem_recibo['payments'].last['receipt_id'].nil?
_, depois = api.(:post, "documents/#{terceira['id']}/payments/#{sem_recibo['payments'].last['id']}/receipt")
ok 'recibo emitido depois, sem enviar', (r = Commerce::Document.find_by(id: depois['payments'].last['receipt_id'])) && r.draft?
api.(:delete, "documents/#{terceira['id']}/payments/#{manual['id']}")
ok 'apagar o pagamento anula o recibo', recibo_manual.reload.void?

# --- o recibo como documento ------------------------------------------------------
_, editado = api.(:patch, "documents/#{recibo.id}", { notes: 'Gracias por su pago', items: [{ name: 'x', quantity: '1', unit_price: '999' }] })
ok 'recibo: textos editam, valor nao', editado['notes'] == 'Gracias por su pago' && editado['total'] == '100.0' && editado['items'].empty?
ok 'recibo nao se cria pela API: 400', api.(:post, 'documents', { kind: 'receipt' }).first == 400
ok 'recibo nao se apaga: 401', api.(:delete, "documents/#{r.id}").first == 401
_, recibos = api.(:get, 'documents?kind=receipt')
ok 'lista de recibos', recibos['payload'].size == 5
account.commerce_profile.update!(receipt_prefix: 'RC')
_, quarta = api.(:post, "documents/#{terceira['id']}/payments", { amount: '5', paid_on: Date.current.to_s, send_receipt: true })
ok 'prefixo do recibo editavel', quarta['payments'].last['receipt_number'].start_with?('RC-')
api.(:patch, "payment_providers/#{provider.id}", { active: false })
s.get pagina.(Commerce::Document.find(terceira['id']))
ok 'provedor desligado: sem botao Pagar', s.response.body.exclude?('id="pay"')
