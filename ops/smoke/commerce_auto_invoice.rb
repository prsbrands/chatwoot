# Fatura automática no aceite (commerce_profiles.auto_invoice_on_accept,
# Commerce::AutoInvoiceJob) contra Postgres/Redis descartáveis. E-mail em :test,
# CSRF desligado para o POST da página pública e jobs no TestAdapter.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

ActionMailer::Base.delivery_method = :test
ActionController::Base.allow_forgery_protection = false
ActiveJob::Base.queue_adapter = :test

account = Account.create!(name: 'Auto', locale: 'es')
account.enable_features!('commerce')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@auto.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
inbox = account.inboxes.create!(name: 'WA', channel: Channel::Api.create!(account: account, webhook_url: 'https://wa.test/hook'))
contact = account.contacts.create!(name: 'María Pérez', email: 'maria@cliente.test')
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

cotacao = lambda do
  _, cot = api.(:post, 'documents', { kind: 'quote', contact_id: contact.id, conversation_id: conversa.id, language: 'es', tax_mode: 'exempt',
                                      customer: { name: 'María Pérez' }, items: [{ name: 'Cortina', quantity: '2', unit: 'unit', unit_price: '50' }] })
  api.(:post, "documents/#{cot['id']}/deliver", { channel: 'conversation', conversation_id: conversa.display_id })
  api.(:post, "documents/#{cot['id']}/deliver", { channel: 'email', to: 'maria@cliente.test' })
  Commerce::Document.find(cot['id'])
end
aceitar = lambda do |cot|
  enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.size
  s.post "/d/#{cot.public_token}/accept"
  ActiveJob::Base.queue_adapter.enqueued_jobs[enqueued..].select { |j| j['job_class'] == 'Commerce::AutoInvoiceJob' }
end

_, perfil = api.(:get, 'profile')
ok 'perfil: fatura automatica desligada por padrao', perfil['auto_invoice_on_accept'] == false

c1 = cotacao.()
ok 'cotacao enviada pela conversa e e-mail', c1.sent? && c1.conversation == conversa && c1.delivered_email == 'maria@cliente.test'
ok 'desligada: aceite nao agenda a fatura', aceitar.(c1).empty? && c1.reload.accepted?
nota = conversa.messages.where(private: true).reorder(:id).last
ok 'desligada: aceite deixa nota mencionando o admin, com o link da cotacao', nota.content.include?("mention://user/#{ana.id}/") &&
                                                                             nota.content.include?("accepted the quote #{c1.number}") &&
                                                                             nota.content.include?("/documents/#{c1.id}")

st, perfil = api.(:patch, 'profile', { auto_invoice_on_accept: true })
ok 'ligar pela tela', st == 200 && perfil['auto_invoice_on_accept'] == true

c2 = cotacao.()
jobs = aceitar.(c2)
ok 'ligada: aceite agenda a fatura', jobs.size == 1 && c2.reload.accepted?
ultima = conversa.messages.maximum(:id)
emails = ActionMailer::Base.deliveries.size
Commerce::AutoInvoiceJob.perform_now(c2.id)
fatura = Commerce::Document.invoice.find_by(source_document_id: c2.id)
ok 'fatura nasce da cotacao, enviada', fatura && fatura.sent? && fatura.total == c2.total && fatura.conversation == conversa &&
                                       fatura.delivered_email == 'maria@cliente.test'
novas = conversa.messages.where('id > ?', ultima).to_a
ok 'fatura vai pela conversa: o PDF e o texto com o link', novas.any? { |m| !m.private && m.attachments.any? } &&
                                                        novas.any? { |m| !m.private && m.content.to_s.include?('Te enviamos la factura') && m.content.include?('/d/') }
ok 'nota interna mencionando o admin, com o link da fatura', novas.any? { |m| m.private && m.content.include?(fatura.number) && m.content.include?(c2.number) &&
                                                                                   m.content.include?("mention://user/#{ana.id}/") && m.content.include?("/documents/#{fatura.id}") }
ok 'fatura vai pelo e-mail da cotacao', ActionMailer::Base.deliveries.size == emails + 1 && ActionMailer::Base.deliveries.last.to == ['maria@cliente.test']

Commerce::AutoInvoiceJob.perform_now(c2.id)
ok 'job repetido nao gera outra fatura', Commerce::Document.invoice.where(source_document_id: c2.id).count == 1
ok 'aceitar de novo pelo link nao agenda outra', aceitar.(c2).empty?

c3 = cotacao.()
s.post "/d/#{c3.public_token}/decline"
nota = conversa.messages.where(private: true).reorder(:id).last
ok 'recusa pelo link: recusada, nota mencionando o admin', c3.reload.declined? && nota.content.include?("declined the quote #{c3.number}") &&
                                                          nota.content.include?("mention://user/#{ana.id}/")
s.post "/d/#{c3.public_token}/decline"
ok 'recusar de novo nao repete a nota', conversa.messages.where(private: true).reorder(:id).last.id == nota.id
ok 'recusar nao gera fatura', ActiveJob::Base.queue_adapter.enqueued_jobs.none? { |j| j['job_class'] == 'Commerce::AutoInvoiceJob' && j['arguments'] != [c2.id] }
