# Comercial, fase 4b: a vitrine pública do catálogo (/c/:token) contra Postgres
# e Redis descartáveis. ACTIVE_STORAGE_SERVICE=local: as fotos ficam no disco
# do container do teste.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Loja', locale: 'es')
account.enable_features!('commerce')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => ana.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

cortinas = account.commerce_categories.create!(name: 'Cortinas')
servicos = account.commerce_categories.create!(name: 'Servicios')
cortina = account.commerce_items.create!(name: 'Cortina roller', price: 35.5, currency: 'USD', unit: 'm2', category: cortinas, description: 'Blackout')
png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
cortina.images.attach(io: StringIO.new(png), filename: 'cortina.png', content_type: 'image/png')
account.commerce_items.create!(name: 'Proyecto a medida', kind: :service, category: servicos)
account.commerce_items.create!(name: 'Plan Pro', price: 49.9, currency: 'USD', billing_interval: :month, kind: :service, category: servicos)
account.commerce_items.create!(name: 'Agotado', price: 10, available: false)

_, perfil = api.(:get, 'profile')
ok 'vitrine nasce desligada, sem link', perfil['storefront_enabled'] == false && perfil['storefront_url'].nil?
_, perfil = api.(:patch, 'profile', { trade_name: 'Loja Bonita', whatsapp: '+507 6123-4567', storefront_enabled: true })
link = URI(perfil['storefront_url'].to_s).path
ok 'ligar cria o link', perfil['storefront_enabled'] && link.start_with?('/c/')

s.get link
corpo = s.response.body
ok 'vitrine com os disponiveis, preco, unidade e plano', s.response.status == 200 && corpo.include?('Cortina roller') &&
                                                        corpo.include?('$ 35,50 / m²') && corpo.include?('$ 49,90 por mes') &&
                                                        corpo.include?('A cotizar') && corpo.exclude?('Agotado')
ok 'foto do item', corpo.include?('<img') && corpo.include?('cortina.png')
ok 'botao abre o WhatsApp com a mensagem do item', corpo.include?('https://wa.me/50761234567?text=Hola%2C%20me%20interesa%3A%20Cortina%20roller')
ok 'filtro por categoria', corpo.include?('Servicios') && corpo.include?('class="chip on"')
s.get link, params: { category: servicos.id }
ok 'categoria escolhida mostra so os dela', s.response.body.include?('Plan Pro') && s.response.body.exclude?('Cortina roller')
s.get link, params: { lang: 'pt' }
ok 'idioma pelo parametro', s.response.body.include?('Quero este') && s.response.body.include?('Sob orçamento')

api.(:patch, 'profile', { whatsapp: '', email: 'ventas@loja.test' })
s.get link
ok 'sem WhatsApp, o botao abre o e-mail', s.response.body.include?('mailto:ventas@loja.test')

token = Commerce::Profile.for(account).storefront_token
api.(:patch, 'profile', { storefront_enabled: false })
s.get link
ok 'desligada: 404', s.response.status == 404
api.(:patch, 'profile', { storefront_enabled: true })
ok 'religar mantem o mesmo link', Commerce::Profile.for(account).storefront_token == token
account.disable_features!('commerce')
s.get link
ok 'conta sem a flag commerce: 404', s.response.status == 404
s.get '/c/nao-existe'
ok 'token desconhecido: 404', s.response.status == 404
