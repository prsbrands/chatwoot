# Comercial, fase 3d no Mercado Pago (preapproval pendente que o cliente conclui
# no init_point) contra Postgres e Redis descartáveis. A API do Mercado Pago
# entra falsa (class_eval no request do gateway); a assinatura x-signature é
# calculada como o Mercado Pago faz. O recibo (Commerce::ReceiptJob) roda na
# hora; e-mail em :test. Também o fim das canceladas no fim do período
# (Commerce::SubscriptionExpiryJob).
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
jobs = ActiveJob::QueueAdapters::TestAdapter.new
jobs.perform_enqueued_jobs = true
jobs.filter = [Commerce::ReceiptJob]
ActiveJob::Base.queue_adapter = jobs

module FakeMp
  PREAPPROVALS = {}
  CHARGES = {}
  PAYMENTS = {}
  PUTS = []

  def self.call(verb, path, body)
    case [verb, path]
    in [:get, '/users/me'] then { 'id' => 1, 'site_id' => 'MLB' }
    in [:post, '/preapproval']
      id = "pre_#{PREAPPROVALS.size + 1}"
      PREAPPROVALS[id] = body.merge('id' => id)
      { 'id' => id, 'init_point' => "https://www.mercadopago.com.br/subscriptions/checkout?preapproval_id=#{id}", 'status' => 'pending' }
    in [:get, %r{\A/preapproval/}] then PREAPPROVALS.fetch(path.split('/').last)
    in [:put, %r{\A/preapproval/}] then PUTS << [path.split('/').last, body]
    in [:get, %r{\A/authorized_payments/}] then CHARGES.fetch(path.split('/').last)
    in [:get, %r{\A/v1/payments/}] then PAYMENTS.fetch(path.split('/').last)
    end
  end
end

Commerce::Gateways::MercadoPago.class_eval do
  private

  def request(verb, path, query: nil, body: nil) = FakeMp.call(verb, path, body&.deep_stringify_keys)
end

account = Account.create!(name: 'Loja BR', locale: 'pt_BR')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
inbox = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/hook'))
contact = account.contacts.create!(name: 'João Silva', email: 'joao@cliente.test')
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversa = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => ana.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

_, prov = api.(:post, 'payment_providers', { provider: 'mercado_pago', environment: 'production', credentials: { access_token: 'APP_USR-123-abcd' } })
provider = Commerce::PaymentProvider.find(prov['id'])
_, cartao = api.(:post, 'payment_methods', { name: 'Cartão MP', kind: 'card', provider_id: provider.id })
_, plano_usd = api.(:post, 'items', { name: 'Plano USD', price: '10', currency: 'USD', billing_interval: 'month' })
_, plano = api.(:post, 'items', { name: 'Plano Anual', price: '1200', currency: 'BRL', billing_interval: 'year' })
_, formas = api.(:get, 'payment_methods')
ok 'forma do Mercado Pago cobra assinatura', formas['payload'].first['charges_subscriptions'] == true
ok 'plano em USD no Mercado Pago (so BRL): 422',
   api.(:post, 'subscriptions', { contact_id: contact.id, item_id: plano_usd['id'], payment_method_id: cartao['id'] }).first == 422
st, assinatura = api.(:post, 'subscriptions', { contact_id: contact.id, item_id: plano['id'], payment_method_id: cartao['id'] })
sub = Commerce::Subscription.find_by(id: assinatura&.dig('id'))
ok 'assinatura anual em BRL criada', st == 200 && sub.pending? && sub.year? && sub.language == 'pt'
api.(:post, "subscriptions/#{sub.id}/deliver", { conversation_id: conversa.display_id })

# --- o cliente assina -----------------------------------------------------------
link = URI(sub.public_url).path
s.get link
ok 'pagina pede o e-mail da conta Mercado Pago', s.response.body.include?('E-mail da sua conta Mercado Pago') &&
                                                s.response.body.include?('value="joao@cliente.test"') && s.response.body.include?('por ano')
s.post "#{link}/subscribe", params: { payer_email: ' outro@mp.test ' }
pre = FakeMp::PREAPPROVALS['pre_1']
ok 'assinar cria o preapproval pendente com o valor do servidor',
   s.response.status == 302 && s.response.location.include?('preapproval_id=pre_1') && pre['status'] == 'pending' &&
   pre['payer_email'] == 'outro@mp.test' && pre['external_reference'] == "subscription-#{sub.id}" &&
   pre['auto_recurring'] == { 'frequency' => 12, 'frequency_type' => 'months', 'currency_id' => 'BRL', 'transaction_amount' => 1200.0 } &&
   pre['back_url'] == sub.public_url && sub.reload.external_id.nil?
s.get "#{link}?preapproval_id=pre_1"
ok 'na volta, avisa que a confirmacao chega', s.response.body.include?('Recebemos a sua assinatura') && s.response.body.exclude?('Assinar com')

aviso = lambda do |id, tipo, assinatura: nil, request_id: 'req-1'|
  headers = { 'Content-Type' => 'application/json', 'x-request-id' => request_id }
  headers['x-signature'] = assinatura if assinatura
  s.post "/commerce/webhooks/mercado_pago/#{provider.webhook_token}?data.id=#{id}&type=#{tipo}",
         params: { action: 'updated', type: tipo, data: { id: id.to_s } }.to_json, headers: headers
  s.response.status
end

FakeMp::PREAPPROVALS['pre_1']['status'] = 'authorized'
ok 'preapproval autorizado liga a assinatura', aviso.('pre_1', 'subscription_preapproval') == 200 && sub.reload.external_id == 'pre_1' && sub.pending?
FakeMp::CHARGES['7001'] = { 'id' => 7001, 'preapproval_id' => 'pre_1', 'transaction_amount' => 1200.0, 'status' => 'processed',
                            'debit_date' => '2026-10-06T10:00:00.000-03:00', 'payment' => { 'id' => 555, 'status' => 'approved' } }
ok 'cobranca aprovada: 200', aviso.(7001, 'subscription_authorized_payment') == 200
sub.reload
fatura = sub.invoices.first
recibo = fatura&.payments&.first&.receipt
ok 'assinatura ativa ate o fim do ano pago', sub.active? && sub.current_period_end.to_date == Date.new(2027, 10, 6)
ok 'fatura do ciclo paga e recibo pela conversa e e-mail', fatura&.paid? && fatura.total == 1200 && recibo&.sent? &&
                                                          conversa.messages.where(private: false).last.content.include?(recibo.number) &&
                                                          ActionMailer::Base.deliveries.last.to == ['joao@cliente.test']
aviso.(7001, 'subscription_authorized_payment')
ok 'aviso repetido nao cobra duas vezes', sub.invoices.count == 1
FakeMp::PAYMENTS['555'] = { 'id' => 555, 'status' => 'approved', 'transaction_amount' => 1200.0, 'external_reference' => "subscription-#{sub.id}" }
ok 'o pagamento do ciclo como aviso payment nao paga checkout nenhum',
   aviso.(555, 'payment') == 200 && account.commerce_checkouts.count == 1 && Commerce::DocumentPayment.where(account: account).count == 1

FakeMp::CHARGES['7002'] = { 'id' => 7002, 'preapproval_id' => 'pre_1', 'transaction_amount' => 1200.0, 'status' => 'recycling',
                            'debit_date' => '2027-10-06T10:00:00.000-03:00', 'payment' => { 'id' => 556, 'status' => 'rejected' } }
aviso.(7002, 'subscription_authorized_payment')
ok 'cobranca recusada: em atraso, com nota', sub.reload.past_due? && conversa.messages.where(private: true).last.content.include?('declined')

api.(:patch, "payment_providers/#{provider.id}", { webhook_secret: 'segredo-mp' })
ts = Time.now.to_i
assinar = ->(id, req, segredo = 'segredo-mp') { "ts=#{ts},v1=#{OpenSSL::HMAC.hexdigest('SHA256', segredo, "id:#{id};request-id:#{req};ts:#{ts};")}" }
FakeMp::CHARGES['7002']['payment']['status'] = 'approved'
ok 'assinatura do aviso errada: 400', aviso.(7002, 'subscription_authorized_payment', assinatura: assinar.(7002, 'r2', 'outro'), request_id: 'r2') == 400 &&
                                      sub.reload.past_due?
ok 'assinatura certa: renovacao paga, volta a ativa',
   aviso.(7002, 'subscription_authorized_payment', assinatura: assinar.(7002, 'r3'), request_id: 'r3') == 200 && sub.reload.active? &&
   sub.invoices.count == 2 && sub.current_period_end.to_date == Date.new(2028, 10, 6)

# --- cancelar -----------------------------------------------------------------
_, cancelada = api.(:post, "subscriptions/#{sub.id}/cancel")
ok 'cancelar no fim do periodo: o Mercado Pago para ja, aqui segue ativa',
   cancelada['status'] == 'active' && cancelada['cancel_at_period_end'] && FakeMp::PUTS.last == ['pre_1', { 'status' => 'cancelled' }]
FakeMp::PREAPPROVALS['pre_1']['status'] = 'cancelled'
api.(:patch, "payment_providers/#{provider.id}", { webhook_secret: '' })
aviso.('pre_1', 'subscription_preapproval')
ok 'aviso de cancelado nao encerra antes do fim do periodo', sub.reload.active?
Commerce::SubscriptionExpiryJob.perform_now
ok 'antes do fim, o job nao encerra', sub.reload.active?
sub.update!(current_period_end: 1.minute.ago)
Commerce::SubscriptionExpiryJob.perform_now
ok 'no fim do periodo, o job encerra', sub.reload.canceled?

_, outra = api.(:post, 'subscriptions', { contact_id: contact.id, item_id: plano['id'], payment_method_id: cartao['id'] })
s.post "#{URI(outra['public_url']).path}/subscribe", params: { payer_email: 'joao@cliente.test' }
FakeMp::PREAPPROVALS['pre_2']['status'] = 'authorized'
aviso.('pre_2', 'subscription_preapproval')
FakeMp::PREAPPROVALS['pre_2']['status'] = 'cancelled'
aviso.('pre_2', 'subscription_preapproval')
ok 'cancelada no painel do Mercado Pago: encerra aqui', Commerce::Subscription.find(outra['id']).canceled?
