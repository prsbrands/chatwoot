# Comercial, fase 3c (Yappy, Botón de Pago V2, USD) contra Postgres e Redis
# descartáveis. A API do Yappy entra falsa (class_eval no post do gateway); o
# hash do aviso (IPN, GET) é calculado como o Yappy faz. O recibo
# (Commerce::ReceiptJob) roda na hora; e-mail em :test.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
jobs = ActiveJob::QueueAdapters::TestAdapter.new
jobs.perform_enqueued_jobs = true
jobs.filter = [Commerce::ReceiptJob]
ActiveJob::Base.queue_adapter = jobs

module FakeYappy
  ORDERS = []
  @merchant_ok = true

  class << self
    attr_accessor :merchant_ok, :last_validation

    def call(path, body, headers)
      case path
      when '/payments/validate/merchant'
        self.last_validation = body
        raise Commerce::Gateways::Error, 'Yappy: Comercio no valido (E002)' unless merchant_ok

        { 'token' => 'tok-yappy', 'epochTime' => 1_791_300_000 }
      when '/payments/payment-wc'
        ORDERS << body.merge('authorization' => headers['Authorization'])
        { 'transactionId' => "TX#{ORDERS.size}", 'token' => 't', 'documentName' => 'doc' }
      end
    end
  end
end

Commerce::Gateways::Yappy.class_eval do
  private

  def post(path, body, headers = {}) = FakeYappy.call(path, body.deep_stringify_keys, headers)
end

account = Account.create!(name: 'Tienda PA', locale: 'es')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@tienda.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
contact = account.contacts.create!(name: 'Luis Díaz', email: 'luis@cliente.test')
secreta = Base64.strict_encode64('chave-hmac-teste.resto-ignorado')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => ana.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

# --- conexão --------------------------------------------------------------------
st, = api.(:post, 'payment_providers', { provider: 'yappy', environment: 'sandbox',
                                         credentials: { merchant_id: 'MERCH-1', secret_key: 'nao-e-base64!' } })
ok 'chave secreta invalida: 422', st == 422
FakeYappy.merchant_ok = false
st, erro = api.(:post, 'payment_providers', { provider: 'yappy', environment: 'sandbox', credentials: { merchant_id: 'MERCH-1', secret_key: secreta } })
ok 'comercio recusado pelo Yappy: 422 com o motivo', st == 422 && erro['message'].include?('E002') && account.commerce_payment_providers.none?
FakeYappy.merchant_ok = true
st, prov = api.(:post, 'payment_providers', { provider: 'yappy', environment: 'sandbox', credentials: { merchant_id: 'MERCH-1234', secret_key: secreta } })
provider = Commerce::PaymentProvider.find_by(id: prov&.dig('id'))
ok 'Yappy conectado; dominio padrao e o da instalacao', st == 200 && prov['currencies'] == ['USD'] &&
                                                       FakeYappy.last_validation == { 'merchantId' => 'MERCH-1234', 'urlDomain' => ENV.fetch('FRONTEND_URL') }
ok 'chave secreta cifrada no banco',
   !ActiveRecord::Base.connection.select_value("SELECT credentials FROM commerce_payment_providers WHERE id = #{provider.id}").include?(secreta)
_, yappy = api.(:post, 'payment_methods', { name: 'Yappy', kind: 'yappy', provider_id: provider.id })

fatura_em = lambda do |moeda, preco|
  _, fatura = api.(:post, 'documents', { kind: 'invoice', contact_id: contact.id, language: 'es', currency: moeda, tax_mode: 'exempt',
                                         customer: { name: 'Luis Díaz', email: 'luis@cliente.test' },
                                         items: [{ name: 'Servicio', quantity: '1', unit: 'service', unit_price: preco.to_s }] })
  api.(:post, "documents/#{fatura['id']}/deliver", { channel: 'email', to: 'luis@cliente.test' })[1]
end
caminho = ->(doc) { doc['public_url'].sub(%r{\Ahttps?://[^/]+}, '') }

s.get caminho.(fatura_em.('BRL', 10))
ok 'fatura em BRL: Yappy (so USD) nao aparece', s.response.body.exclude?('id="pay"')
fatura = fatura_em.('USD', 120)
link = caminho.(fatura)
s.get link
ok 'fatura em USD: Pagar con Yappy e o campo do celular', s.response.body.include?('Pagar con Yappy') && s.response.body.include?('name="phone"')

# --- pagar uma parte ----------------------------------------------------------
s.post "#{link}/pay", params: { amount: '50', payment_method_id: yappy['id'] }
ok 'sem celular: 422, nenhuma ordem nem tentativa pendente', s.response.status == 422 && FakeYappy::ORDERS.empty? && account.commerce_checkouts.none?
s.post "#{link}/pay", params: { amount: '50', payment_method_id: yappy['id'], phone: '6123456' }
ok 'celular com 7 digitos: 422', s.response.status == 422 && FakeYappy::ORDERS.empty?
s.post "#{link}/pay", params: { amount: '50', payment_method_id: yappy['id'], phone: '6123-4567' }
checkout = account.commerce_checkouts.last
ordem = FakeYappy::ORDERS.last
ok 'ordem criada com o celular e o valor do servidor; volta para a pagina',
   s.response.status == 302 && s.response.location.end_with?("?checkout=#{checkout.id}") && checkout.external_id == "CG#{checkout.id}" &&
   ordem['aliasYappy'] == '61234567' && ordem['total'] == '50.00' && ordem['ipnUrl'] == provider.webhook_url &&
   ordem['authorization'] == 'tok-yappy' && ordem['paymentDate'] == 1_791_300_000 && ordem['domain'] == ENV.fetch('FRONTEND_URL')
s.get s.response.location.sub(%r{\Ahttps?://[^/]+}, '')
ok 'pagina espera a aprovacao no app, sem recarregar e sem o formulario',
   s.response.body.include?('Te solicitan un Yappy') && s.response.body.include?('id="waiting"') &&
   s.response.body.exclude?('http-equiv="refresh"') && s.response.body.exclude?('id="pay"')
situacao = lambda do |tentativa|
  s.get "#{link}/checkouts/#{tentativa.id}", headers: { 'Accept' => 'application/json' }
  JSON.parse(s.response.body)['status']
end
ok 'consulta leve da situacao: pendente', situacao.(checkout) == 'pending'

hmac = ->(texto) { OpenSSL::HMAC.hexdigest('SHA256', 'chave-hmac-teste', texto) }
ipn = lambda do |pedido, situacao, hash: :certo, dominio: ENV.fetch('FRONTEND_URL')|
  query = { orderId: pedido, status: situacao, domain: dominio, confirmationNumber: 'CONF-1' }
  query[:hash] = hmac.("#{pedido}#{situacao}#{dominio}") if hash == :certo
  query[:hash] = 'f' * 64 if hash == :errado
  s.get "/commerce/webhooks/yappy/#{provider.webhook_token}", params: query
  s.response.status
end

ok 'aviso sem hash: 400', ipn.(checkout.external_id, 'E', hash: nil) == 400 && checkout.reload.pending?
ok 'aviso com hash errado: 400', ipn.(checkout.external_id, 'E', hash: :errado) == 400 && checkout.reload.pending?
ok 'aviso executado (E) com hash certo: 200', ipn.(checkout.external_id, 'E') == 200
fat = Commerce::Document.find(fatura['id'])
pagamento = fat.payments.last
ok 'consulta leve da situacao: paga', situacao.(checkout) == 'paid'
ok 'fatura parcial com o valor da ordem', fat.partially_paid? && fat.amount_paid == 50 && checkout.reload.paid? && pagamento.online? &&
                                          pagamento.note.include?('CONF-1')
ok 'recibo enviado', pagamento.receipt&.sent? && ActionMailer::Base.deliveries.last.subject.start_with?('Recibo')
ipn.(checkout.external_id, 'E')
ok 'aviso repetido nao paga de novo', fat.payments.count == 1
s.get "#{link}?checkout=#{checkout.id}"
ok 'pagina confirma o pagamento e volta o formulario', s.response.body.include?('Pago recibido') && s.response.body.exclude?('id="waiting"') &&
                                                     s.response.body.include?('id="pay"')

s.post "#{link}/pay", params: { amount: '70', payment_method_id: yappy['id'], phone: '61234567' }
recusado = account.commerce_checkouts.last
ok 'recusado no app (R): tentativa falha, saldo intacto', ipn.(recusado.external_id, 'R') == 200 && recusado.reload.failed? && fat.reload.balance == 70
s.get "#{link}?checkout=#{recusado.id}"
ok 'pagina avisa a recusa e deixa tentar de novo', s.response.body.include?('rechazado o la solicitud venció') && s.response.body.include?('id="pay"')

# --- domínio próprio e prazo ----------------------------------------------------
api.(:patch, "payment_providers/#{provider.id}", { credentials: { merchant_id: 'MERCH-1234', secret_key: secreta, domain: 'https://loja.test' } })
s.post "#{link}/pay", params: { amount: '70', payment_method_id: yappy['id'], phone: '61234567' }
proprio = account.commerce_checkouts.last
ok 'dominio cadastrado no Yappy vai na validacao e na ordem', FakeYappy.last_validation['urlDomain'] == 'https://loja.test' &&
                                                            FakeYappy::ORDERS.last['domain'] == 'https://loja.test'
ok 'aviso com o dominio proprio quita a fatura', ipn.(proprio.external_id, 'E', dominio: 'https://loja.test') == 200 && fat.reload.paid?

s.post "#{caminho.(fatura_em.('USD', 30))}/pay", params: { amount: '30', payment_method_id: yappy['id'], phone: '61234567' }
velho = account.commerce_checkouts.last
velho.update_column(:created_at, 25.hours.ago) # rubocop:disable Rails/SkipsModelValidations
Commerce::CheckoutReconcileJob.perform_now
ok 'sem consulta no Yappy: a conciliacao so expira depois do prazo', velho.reload.expired?
