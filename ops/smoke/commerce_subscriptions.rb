# Comercial, fase 3d (assinaturas pelo Stripe Billing) contra Postgres e Redis
# descartáveis. O Stripe entra falso (class_eval no client), mas a assinatura
# do webhook é a de verdade. O recibo (Commerce::ReceiptJob) roda na hora; os
# outros jobs ficam só enfileirados. E-mail em :test.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
jobs = ActiveJob::QueueAdapters::TestAdapter.new
jobs.perform_enqueued_jobs = true
jobs.filter = [Commerce::ReceiptJob]
ActiveJob::Base.queue_adapter = jobs

module FakeStripe
  SESSIONS = {}
  ENDPOINTS = {}
  SUBSCRIPTIONS = {}
  CALLS = []

  module Sessions
    def self.create(params, _opts = {})
      id = "cs_test_#{SecureRandom.hex(4)}"
      SESSIONS[id] = params
      Stripe::StripeObject.construct_from(id: id, url: "https://checkout.stripe.test/#{id}")
    end
  end

  module Endpoints
    def self.create(params)
      id = "we_#{SecureRandom.hex(4)}"
      ENDPOINTS[id] = params
      Stripe::StripeObject.construct_from(id: id, secret: "whsec_#{SecureRandom.hex(8)}")
    end

    def self.update(id, params) = ENDPOINTS[id] = ENDPOINTS.fetch(id).merge(params)
  end

  module Subscriptions
    def self.retrieve(id) = Stripe::StripeObject.construct_from(SUBSCRIPTIONS.fetch(id))
    def self.update(id, params) = CALLS << [:update, id, params]
    def self.cancel(id) = CALLS << [:cancel, id]
  end

  module Client
    def self.v1 = self
    def self.checkout = self
    def self.sessions = Sessions
    def self.webhook_endpoints = Endpoints
    def self.subscriptions = Subscriptions
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
contact = account.contacts.create!(name: 'María Pérez', email: 'maria@cliente.test', additional_attributes: { 'billing_tax_id' => '8-123-456' })
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversa = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
deal = Sales::Deal.open_for_contact!(contact, conversation: conversa)
transferencia = account.commerce_payment_methods.create!(name: 'Transferencia', kind: :bank_transfer)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil, user: ana|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

_, prov = api.(:post, 'payment_providers', { provider: 'stripe', environment: 'sandbox', credentials: { secret_key: 'sk_test_abc123wxyz' } })
provider = Commerce::PaymentProvider.find(prov['id'])
_, cartao = api.(:post, 'payment_methods', { name: 'Tarjeta', kind: 'card', provider_id: provider.id })

# --- plano no catálogo --------------------------------------------------------
st, plano = api.(:post, 'items', { name: 'Plan Pro', kind: 'service', price: '49.90', currency: 'USD', billing_interval: 'month' })
ok 'plano mensal no catalogo', st == 200 && plano['billing_interval'] == 'month'
ok 'plano sem preco: 422', api.(:post, 'items', { name: 'Plan X', billing_interval: 'year' }).first == 422
_, avulso = api.(:post, 'items', { name: 'Instalacion', price: '10', currency: 'USD' })
ok 'item avulso continua one_time', avulso['billing_interval'] == 'one_time'

# --- criar e enviar -------------------------------------------------------------
nova = ->(item, metodo, user: ana) { api.(:post, 'subscriptions', { contact_id: contact.id, item_id: item['id'], payment_method_id: metodo, quantity: '2' }, user: user) }
ok 'item avulso nao vira assinatura: 422', nova.(avulso, cartao['id']).first == 422
ok 'forma offline nao assina: 422', nova.(plano, transferencia.id).first == 422
st, assinatura = nova.(plano, cartao['id'], user: beto)
sub = Commerce::Subscription.find_by(id: assinatura&.dig('id'))
ok 'agente cria a assinatura: copia plano, cliente e negocio', st == 200 && assinatura['status'] == 'pending' && assinatura['amount'] == '99.8' &&
                                                             assinatura['interval'] == 'month' && assinatura['customer']['tax_id'] == '8-123-456' &&
                                                             sub.deal == deal && sub.provider == provider
ok 'agente nao cancela: 401', api.(:post, "subscriptions/#{sub.id}/cancel", nil, user: beto).first == 401
st, = api.(:post, "subscriptions/#{sub.id}/deliver", { conversation_id: conversa.display_id }, user: beto)
ok 'link enviado pela conversa', st == 200 && conversa.messages.last.content.include?(sub.public_url) && sub.reload.conversation == conversa &&
                                 sub.sent_at.present?

# --- o cliente assina -----------------------------------------------------------
link = URI(sub.public_url).path
s.get link
ok 'pagina publica do plano', s.response.status == 200 && s.response.body.include?('Suscribirse con Tarjeta') && s.response.body.include?('por mes')
s.post "#{link}/subscribe"
enviado = FakeStripe::SESSIONS.values.last
ok 'assinar abre o Stripe no modo assinatura, com o valor do servidor',
   s.response.status == 302 && s.response.location.start_with?('https://checkout.stripe.test/') && enviado[:mode] == 'subscription' &&
   enviado[:line_items][0][:price_data][:unit_amount] == 9980 && enviado[:line_items][0][:price_data][:recurring] == { interval: 'month' } &&
   enviado[:subscription_data][:metadata][:cortexgen_subscription_id] == sub.id && enviado[:customer_email] == 'maria@cliente.test'
ok 'webhook passa a ouvir os eventos de assinatura', FakeStripe::ENDPOINTS[provider.webhook_endpoint_id][:enabled_events].include?('invoice.paid')
s.get "#{link}?session_id=cs_test_1"
ok 'na volta, avisa que a confirmacao chega', s.response.body.include?('Recibimos tu suscripción') && s.response.body.exclude?('Suscribirse con')

webhook = lambda do |tipo, objeto, secret: provider.webhook_secret|
  payload = { id: "evt_#{SecureRandom.hex(4)}", object: 'event', type: tipo, data: { object: objeto } }.to_json
  agora = Time.now
  assinatura = Stripe::Webhook::Signature.generate_header(agora, Stripe::Webhook::Signature.compute_signature(agora, payload, secret))
  s.post "/commerce/webhooks/stripe/#{provider.webhook_token}", params: payload,
                                                                 headers: { 'Content-Type' => 'application/json', 'Stripe-Signature' => assinatura }
  s.response.status
end
ciclo = lambda do |id, inicio, valor: 9980, sub_id: 'sub_1'|
  { id: id, object: 'invoice', amount_paid: valor, currency: 'usd', parent: { subscription_details: { subscription: sub_id } },
    lines: { object: 'list', data: [{ period: { start: inicio.to_i, end: (inicio + 1.month).to_i } }] } }
end

FakeStripe::SUBSCRIPTIONS['sub_1'] = { id: 'sub_1', metadata: { cortexgen_subscription_id: sub.id.to_s } }
inicio = Time.zone.parse('2026-10-06 12:00')
ok 'assinatura errada no webhook: 400', webhook.('invoice.paid', ciclo.('in_1', inicio), secret: 'whsec_falso') == 400 && sub.reload.pending?
ok 'primeiro ciclo antes do checkout.session: 200', webhook.('invoice.paid', ciclo.('in_1', inicio)) == 200
sub.reload
fatura = sub.invoices.first
recibo = fatura&.payments&.first&.receipt
ok 'assinatura ativa, ligada pelo metadata, com o periodo', sub.active? && sub.external_id == 'sub_1' &&
                                                         sub.current_period_end.to_date == Date.new(2026, 11, 6)
ok 'fatura do ciclo paga, com a linha da assinatura e o periodo',
   fatura&.paid? && fatura.total == BigDecimal('99.8') && fatura.items.first.quantity == 2 && fatura.items.first.description == '06/10/2026 – 06/11/2026' &&
   fatura.period_start == Date.new(2026, 10, 6) && fatura.payments.first.online?
ok 'recibo enviado pela conversa e pelo e-mail, com nota interna',
   recibo.present? && conversa.messages.where(private: false).last.content.include?(recibo.number) &&
   ActionMailer::Base.deliveries.last&.to == ['maria@cliente.test'] && conversa.messages.where(private: true).last.content.include?('Online payment received')
ok 'negocio ganho no primeiro ciclo', deal.reload.won?
webhook.('invoice.paid', ciclo.('in_1', inicio))
ok 'aviso repetido nao cobra duas vezes', sub.invoices.count == 1 && account.commerce_documents.receipt.count == 1
ok 'checkout.session da assinatura so liga', webhook.('checkout.session.completed', { id: 'cs_test_1', object: 'checkout.session', mode: 'subscription',
                                                                                     status: 'complete', subscription: 'sub_1' }) == 200 &&
                                              sub.reload.external_id == 'sub_1' && sub.invoices.count == 1

webhook.('invoice.payment_failed', ciclo.('in_2', inicio + 1.month))
ok 'renovacao recusada: em atraso, com nota', sub.reload.past_due? && conversa.messages.where(private: true).last.content.include?('declined') &&
                                              sub.invoices.count == 1
webhook.('invoice.paid', ciclo.('in_2', inicio + 1.month))
ok 'renovacao paga: segunda fatura e volta a ativa', sub.reload.active? && sub.invoices.count == 2 && sub.current_period_end.to_date == Date.new(2026, 12, 6)
_, detalhe = api.(:get, "subscriptions/#{sub.id}")
ok 'detalhe com as faturas e recibos', detalhe['invoices'].size == 2 && detalhe['invoices'].all? { |i| i['status'] == 'paid' && i['receipts'].size == 1 }
FakeStripe::SUBSCRIPTIONS['sub_9'] = { id: 'sub_9', metadata: {} }
ok 'aviso de assinatura de fora: 200, nada muda',
   webhook.('invoice.paid', ciclo.('in_9', inicio, sub_id: 'sub_9')) == 200 && account.commerce_documents.invoice.count == 2

# --- cancelar -----------------------------------------------------------------
st, cancelada = api.(:post, "subscriptions/#{sub.id}/cancel")
ok 'cancelar no fim do periodo: avisa o Stripe e segue ativa', st == 200 && cancelada['status'] == 'active' && cancelada['cancel_at_period_end'] &&
                                                                 FakeStripe::CALLS.last == [:update, 'sub_1', { cancel_at_period_end: true }]
s.get link
ok 'pagina mostra quando termina', s.response.body.include?('Se cancela el 06/12/2026')
webhook.('customer.subscription.deleted', { id: 'sub_1', object: 'subscription' })
ok 'fim no Stripe cancela aqui', sub.reload.canceled? && sub.canceled_at.present?
s.get link
ok 'pagina da cancelada, sem botao', s.response.body.include?('Suscripción cancelada') && s.response.body.exclude?('Suscribirse con')

_, outra = nova.(plano, cartao['id'])
chamadas = FakeStripe::CALLS.size
st, outra = api.(:post, "subscriptions/#{outra['id']}/cancel", { at_period_end: false })
ok 'cancelar a que ninguem assinou: so aqui', st == 200 && outra['status'] == 'canceled' && FakeStripe::CALLS.size == chamadas
s.post "#{URI(outra['public_url']).path}/subscribe"
ok 'cancelada nao assina: 422', s.response.status == 422
_, lista = api.(:get, 'subscriptions?status=canceled')
ok 'lista por situacao', lista['payload'].size == 2
