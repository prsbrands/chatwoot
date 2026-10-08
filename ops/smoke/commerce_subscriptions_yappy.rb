# Comercial, fase 3d no Yappy: cobrança assistida (sem débito automático) contra
# Postgres e Redis descartáveis. A API do Yappy entra falsa (class_eval no post
# do gateway); o hash do aviso (IPN) é calculado como o Yappy faz. O recibo
# (Commerce::ReceiptJob) roda na hora; e-mail em :test. As datas do ciclo são
# ajustadas no banco para o Commerce::SubscriptionCycleJob agir.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
jobs = ActiveJob::QueueAdapters::TestAdapter.new
jobs.perform_enqueued_jobs = true
jobs.filter = [Commerce::ReceiptJob]
ActiveJob::Base.queue_adapter = jobs

Commerce::Gateways::Yappy.class_eval do
  private

  def post(path, _body, _headers = {})
    path.end_with?('merchant') ? { 'token' => 'tok', 'epochTime' => 1 } : { 'transactionId' => 'TX', 'token' => 't', 'documentName' => 'd' }
  end
end

account = Account.create!(name: 'Tienda PA', locale: 'es')
account.enable_features!('commerce', 'sales_pipeline')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@tienda.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
inbox = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/hook'))
contact = account.contacts.create!(name: 'Luis Díaz', email: 'luis@cliente.test')
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversa = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
secreta = Base64.strict_encode64('chave-hmac-teste.resto-ignorado')

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => ana.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end
caminho = ->(url) { URI(url).path }

_, prov = api.(:post, 'payment_providers', { provider: 'yappy', environment: 'sandbox', credentials: { merchant_id: 'M-1', secret_key: secreta } })
provider = Commerce::PaymentProvider.find(prov['id'])
_, yappy = api.(:post, 'payment_methods', { name: 'Yappy', kind: 'yappy', provider_id: provider.id })
_, plano = api.(:post, 'items', { name: 'Plan Mensual', price: '25', currency: 'USD', billing_interval: 'month' })
_, formas = api.(:get, 'payment_methods')
ok 'forma do Yappy cobra assinatura', formas['payload'].first['charges_subscriptions'] == true
st, assinatura = api.(:post, 'subscriptions', { contact_id: contact.id, item_id: plano['id'], payment_method_id: yappy['id'] })
sub = Commerce::Subscription.find_by(id: assinatura&.dig('id'))
ok 'assinatura mensal no Yappy criada', st == 200 && sub.pending? && sub.assisted?
api.(:post, "subscriptions/#{sub.id}/deliver", { conversation_id: conversa.display_id })

# --- o cliente assina: primeira fatura -------------------------------------------
link = caminho.(sub.public_url)
s.get link
ok 'pagina explica a cobranca assistida', s.response.body.include?('te enviamos la factura de la renovación') &&
                                         s.response.body.include?('Suscribirse con Yappy')
s.post "#{link}/subscribe"
primeira = sub.invoices.first
ok 'assinar abre a fatura do primeiro ciclo, vencendo hoje', s.response.status == 302 && primeira &&
                                                             s.response.location == Commerce::DocumentFlow.new(primeira).public_url &&
                                                             primeira.sent? && primeira.due_date == Date.current &&
                                                             primeira.period_end == Date.current + 1.month && sub.reload.pending?
s.post "#{link}/subscribe"
ok 'assinar de novo volta para a mesma fatura', sub.invoices.count == 1 && s.response.location.end_with?(primeira.public_token)

pagina = caminho.(Commerce::DocumentFlow.new(primeira).public_url)
s.post "#{pagina}/pay", params: { amount: '25', payment_method_id: yappy['id'], phone: '61234567' }
checkout = account.commerce_checkouts.last
hmac = ->(texto) { OpenSSL::HMAC.hexdigest('SHA256', 'chave-hmac-teste', texto) }
dominio = ENV.fetch('FRONTEND_URL')
s.get "/commerce/webhooks/yappy/#{provider.webhook_token}",
      params: { orderId: checkout.external_id, status: 'E', domain: dominio, confirmationNumber: 'C1', hash: hmac.("#{checkout.external_id}E#{dominio}") }
sub.reload
ok 'pago no Yappy: assinatura ativa por um mes', primeira.reload.paid? && sub.active? && sub.current_period_end.to_date == Date.current + 1.month
ok 'recibo pela conversa', conversa.messages.where(private: false).last.content.include?(primeira.payments.first.receipt.number)

# --- renovação -------------------------------------------------------------------
Commerce::SubscriptionCycleJob.perform_now
ok 'longe do vencimento: nenhuma fatura nova', sub.invoices.count == 1
sub.update!(current_period_end: 2.days.from_now)
emails = ActionMailer::Base.deliveries.size
Commerce::SubscriptionCycleJob.perform_now
segunda = sub.invoices.last
ok '3 dias antes: fatura do ciclo seguinte, vencendo no fim do periodo', sub.invoices.count == 2 && segunda.sent? &&
                                                                       segunda.due_date == 2.days.from_now.to_date &&
                                                                       segunda.period_start == 2.days.from_now.to_date
ok 'link da renovacao pela conversa e pelo e-mail', conversa.messages.where(private: false).last.content.include?('se renueva') &&
                                                    conversa.messages.where(private: false).last.content.include?(segunda.public_token) &&
                                                    ActionMailer::Base.deliveries.size == emails + 1
Commerce::SubscriptionCycleJob.perform_now
ok 'job de novo: nao repete a fatura', sub.invoices.count == 2

segunda.update!(due_date: Date.current)
antes = conversa.messages.count
Commerce::SubscriptionCycleJob.perform_now
ok 'no dia do vencimento: lembrete pela conversa (PDF e texto)', conversa.messages.count == antes + 2 && conversa.messages.last.content.include?('vence hoy')
Commerce::SubscriptionCycleJob.perform_now
ok 'lembrete so uma vez', conversa.messages.count == antes + 2

segunda.update!(due_date: 6.days.ago.to_date)
Commerce::SubscriptionCycleJob.perform_now
ok '5 dias sem pagar: em atraso, com nota', sub.reload.past_due? && conversa.messages.where(private: true).last.content.include?('past due')
s.get link
ok 'pagina da assinatura mostra o botao da fatura aberta', s.response.body.include?("Pagar la factura #{segunda.number}")

api.(:post, "documents/#{segunda.id}/payments", { amount: '25', paid_on: Date.current.to_s })
ok 'pagamento a mao da renovacao: volta a ativa com o periodo dela', sub.reload.active? && sub.current_period_end.to_date == segunda.period_end

# --- cancelar -------------------------------------------------------------------
api.(:post, "subscriptions/#{sub.id}/cancel")
sub.update!(current_period_end: 1.day.from_now)
Commerce::SubscriptionCycleJob.perform_now
ok 'cancelada no fim do periodo: nao gera a proxima fatura', sub.reload.active? && sub.cancel_at_period_end && sub.invoices.count == 2

_, outra = api.(:post, 'subscriptions', { contact_id: contact.id, item_id: plano['id'], payment_method_id: yappy['id'] })
s.post "#{caminho.(outra['public_url'])}/subscribe"
aberta = Commerce::Subscription.find(outra['id']).invoices.first
api.(:post, "subscriptions/#{outra['id']}/cancel", { at_period_end: false })
ok 'cancelar na hora anula a fatura sem pagamento', aberta.reload.void? && Commerce::Subscription.find(outra['id']).canceled?
