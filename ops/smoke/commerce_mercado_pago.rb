# Comercial, fase 3b (Mercado Pago Brasil, Checkout Pro com Pix) contra
# Postgres e Redis descartáveis. A API do Mercado Pago entra falsa (class_eval
# no request do gateway); a assinatura x-signature é calculada como o Mercado
# Pago faz. O recibo (Commerce::ReceiptJob) roda na hora; e-mail em :test.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
jobs = ActiveJob::QueueAdapters::TestAdapter.new
jobs.perform_enqueued_jobs = true
jobs.filter = [Commerce::ReceiptJob]
ActiveJob::Base.queue_adapter = jobs

module FakeMp
  PREFERENCES = []
  PAYMENTS = {}
  @site = 'MLB'

  class << self
    attr_accessor :site

    def pay(id, checkout, amount, status = 'approved')
      PAYMENTS[id.to_s] = { 'id' => id, 'status' => status, 'transaction_amount' => amount, 'external_reference' => checkout.to_s }
    end

    def call(verb, path, query, body)
      case [verb, path]
      in [:get, '/users/me'] then { 'id' => 1, 'site_id' => site }
      in [:post, '/checkout/preferences']
        PREFERENCES << body
        id = "pref-#{PREFERENCES.size}"
        { 'id' => id, 'init_point' => "https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=#{id}",
          'sandbox_init_point' => "https://sandbox.mercadopago.com.br/checkout/v1/redirect?pref_id=#{id}" }
      in [:get, '/v1/payments/search'] then { 'results' => PAYMENTS.values.select { |p| p['external_reference'] == query[:external_reference].to_s } }
      in [:get, %r{\A/v1/payments/\w+\z}] then PAYMENTS.fetch(path.split('/').last)
      end
    end
  end
end

Commerce::Gateways::MercadoPago.class_eval do
  private

  def request(verb, path, query: nil, body: nil) = FakeMp.call(verb, path, query, body&.deep_stringify_keys)
end

account = Account.create!(name: 'Loja BR', locale: 'pt_BR')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
contact = account.contacts.create!(name: 'João Silva', email: 'joao@cliente.test')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => ana.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

# --- conexão --------------------------------------------------------------------
FakeMp.site = 'MLA'
st, = api.(:post, 'payment_providers', { provider: 'mercado_pago', environment: 'production', credentials: { access_token: 'APP_USR-arg' } })
ok 'conta do Mercado Pago de outro pais: 422', st == 422 && account.commerce_payment_providers.none?
FakeMp.site = 'MLB'
st, prov = api.(:post, 'payment_providers', { provider: 'mercado_pago', environment: 'production', credentials: { access_token: 'APP_USR-123-abcd' } })
provider = Commerce::PaymentProvider.find_by(id: prov&.dig('id'))
ok 'Mercado Pago Brasil conectado, token cifrado', st == 200 && prov['credential_hint'] == '…abcd' && prov['currencies'] == ['BRL'] &&
                                                   !ActiveRecord::Base.connection.select_value("SELECT credentials FROM commerce_payment_providers WHERE id = #{provider.id}").include?('APP_USR')
_, pix = api.(:post, 'payment_methods', { name: 'Pix e cartão', kind: 'pix', provider_id: provider.id })

fatura_em = lambda do |moeda, preco|
  _, fatura = api.(:post, 'documents', { kind: 'invoice', contact_id: contact.id, language: 'pt', currency: moeda, tax_mode: 'exempt',
                                         customer: { name: 'João Silva', email: 'joao@cliente.test' },
                                         items: [{ name: 'Consultoria', quantity: '1', unit: 'service', unit_price: preco.to_s }] })
  api.(:post, "documents/#{fatura['id']}/deliver", { channel: 'email', to: 'joao@cliente.test' })[1]
end
caminho = ->(doc) { doc['public_url'].sub(%r{\Ahttps?://[^/]+}, '') }

em_dolar = fatura_em.('USD', 100)
s.get caminho.(em_dolar)
ok 'fatura em USD: Mercado Pago (so BRL) nao aparece', s.response.status == 200 && s.response.body.exclude?('id="pay"')

fatura = fatura_em.('BRL', 300)
link = caminho.(fatura)
s.get link
ok 'fatura em BRL: Pagar com Pix e cartao', s.response.body.include?('Pagar com Pix e cartão')

# --- pagar uma parte -----------------------------------------------------------
s.post "#{link}/pay", params: { amount: '150.50', payment_method_id: pix['id'] }
checkout = account.commerce_checkouts.last
pref = FakeMp::PREFERENCES.last
ok 'vai para o Checkout Pro com a preferencia do servidor',
   s.response.status == 302 && s.response.location.start_with?('https://www.mercadopago.com.br/') && checkout.external_id == 'pref-1' &&
   pref['items'][0]['unit_price'] == 150.5 && pref['items'][0]['currency_id'] == 'BRL' && pref['external_reference'] == checkout.id.to_s &&
   pref['notification_url'] == provider.webhook_url && pref['back_urls']['success'].end_with?("?checkout=#{checkout.id}") &&
   pref['auto_return'] == 'approved' && pref['payer']['email'] == 'joao@cliente.test' && pref['expiration_date_to'].present?

aviso = lambda do |id, tipo: 'payment', assinatura: nil, request_id: 'req-1'|
  headers = { 'Content-Type' => 'application/json', 'x-request-id' => request_id }
  headers['x-signature'] = assinatura if assinatura
  s.post "/commerce/webhooks/mercado_pago/#{provider.webhook_token}?data.id=#{id}&type=#{tipo}",
         params: { action: "#{tipo}.updated", type: tipo, data: { id: id.to_s } }.to_json, headers: headers
  s.response.status
end

ok 'aviso de merchant_order: 200, nada muda', aviso.(1, tipo: 'merchant_order') == 200 && checkout.reload.pending?
FakeMp.pay(9001, checkout.id, 150.5, 'pending')
ok 'Pix ainda nao pago: segue pendente', aviso.(9001) == 200 && checkout.reload.pending? && Commerce::DocumentPayment.where(account: account).none?
FakeMp.pay(9001, checkout.id, 150.5)
ok 'Pix aprovado: 200', aviso.(9001) == 200
fat = Commerce::Document.find(fatura['id'])
pagamento = fat.payments.last
ok 'fatura parcial com o pagamento confirmado na API', fat.partially_paid? && fat.amount_paid == BigDecimal('150.5') && checkout.reload.paid? &&
                                                       pagamento.online? && pagamento.note.include?('9001')
recibo = pagamento.receipt
ok 'recibo em portugues enviado por e-mail', recibo&.sent? && ActionMailer::Base.deliveries.last.subject.start_with?('Recibo') &&
                                             recibo.details['balance'] == '149.5'
aviso.(9001)
ok 'aviso repetido nao paga de novo', fat.payments.count == 1

FakeMp.pay(9002, 999_999, 10)
ok 'pagamento que nao e de checkout desta conta: ignorado', aviso.(9002) == 200 && fat.payments.count == 1

# --- assinatura dos webhooks ------------------------------------------------------
api.(:patch, "payment_providers/#{provider.id}", { webhook_secret: 'segredo-mp' })
ok 'chave secreta dos webhooks guardada (cifrada)', provider.reload.webhook_secret == 'segredo-mp' &&
                                                    !ActiveRecord::Base.connection.select_value("SELECT webhook_secret FROM commerce_payment_providers WHERE id = #{provider.id}").include?('segredo')
s.post "#{link}/pay", params: { amount: '149.50', payment_method_id: pix['id'] }
resto = account.commerce_checkouts.last
FakeMp.pay(9003, resto.id, 149.5)
ts = Time.now.to_i
assinar = ->(id, req, segredo = 'segredo-mp') { "ts=#{ts},v1=#{OpenSSL::HMAC.hexdigest('SHA256', segredo, "id:#{id};request-id:#{req};ts:#{ts};")}" }
ok 'assinatura errada: 400, nada pago', aviso.(9003, assinatura: assinar.(9003, 'req-2', 'outro'), request_id: 'req-2') == 400 && resto.reload.pending?
ok 'assinatura certa: fatura paga', aviso.(9003, assinatura: assinar.(9003, 'req-3'), request_id: 'req-3') == 200 && fat.reload.paid?

# --- volta do cliente e conciliação -------------------------------------------
segunda = fatura_em.('BRL', 80)
s.post "#{caminho.(segunda)}/pay", params: { amount: '80', payment_method_id: pix['id'] }
volta = account.commerce_checkouts.last
FakeMp.pay(9004, volta.id, 80)
s.get "#{caminho.(segunda)}?checkout=#{volta.id}"
ok 'na volta, busca o pagamento e confirma', s.response.body.include?('Pagamento recebido') && Commerce::Document.find(segunda['id']).paid?

terceira = fatura_em.('BRL', 40)
s.post "#{caminho.(terceira)}/pay", params: { amount: '40', payment_method_id: pix['id'] }
perdido = account.commerce_checkouts.last
FakeMp.pay(9005, perdido.id, 40)
perdido.update_column(:created_at, 5.minutes.ago) # rubocop:disable Rails/SkipsModelValidations
Commerce::CheckoutReconcileJob.perform_now
ok 'conciliacao encontra o pagamento sem aviso', perdido.reload.paid? && Commerce::Document.find(terceira['id']).paid?

# --- credenciais de teste antigas (TEST-) ------------------------------------------
api.(:patch, "payment_providers/#{provider.id}", { environment: 'sandbox', credentials: { access_token: 'TEST-999-wxyz' } })
quarta = fatura_em.('BRL', 10)
s.post "#{caminho.(quarta)}/pay", params: { amount: '10', payment_method_id: pix['id'] }
ok 'token TEST- usa o sandbox_init_point', s.response.location.to_s.start_with?('https://sandbox.mercadopago.com.br/')
