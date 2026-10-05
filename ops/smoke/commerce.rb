# Comercial, fase 1 (catálogo, categorias, empresa e formas de pagamento)
# contra Postgres/Redis descartáveis. ACTIVE_STORAGE_SERVICE=local: as imagens
# ficam no disco do container do teste.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

account = Account.create!(name: 'Loja', locale: 'es')
outra = Account.create!(name: 'Outra', locale: 'es')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
beto = User.create!(name: 'Beto', email: "beto-#{SecureRandom.hex(3)}@loja.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: beto, role: :agent)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
api = lambda do |verb, path, body = nil, user: ana|
  s.public_send(verb, "/api/v1/accounts/#{account.id}/commerce/#{path}",
                params: body&.to_json, headers: { 'api_access_token' => user.access_token.token, 'Content-Type' => 'application/json' })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

ok 'sem a flag: 401', api.(:get, 'items').first == 401
account.enable_features!('commerce')

_, cat = api.(:post, 'categories', { name: 'Cortinas' })
_, servico = api.(:post, 'items', { kind: 'service', name: 'Instalação de cortina', unit: 'project', category_id: cat['id'] })
ok 'servico sem preco: sob orcamento', servico['price'].nil? && servico['category_name'] == 'Cortinas' && servico['currency'] == 'USD'
_, produto = api.(:post, 'items', { kind: 'product', name: 'Trilho de alumínio', sku: 'TR-1', price: '35.90', currency: 'BRL', unit: 'm' })
ok 'produto com preco e moeda', produto['price'] == '35.9' && produto['currency'] == 'BRL' && produto['unit'] == 'm'
ok 'preco em branco vira sob orcamento', api.(:patch, "items/#{produto['id']}", { price: '' })[1]['price'].nil?
ok 'moeda fora da lista: 422', api.(:post, 'items', { name: 'X', currency: 'ARS' }).first == 422
ok 'unidade fora da lista: 422', api.(:post, 'items', { name: 'X', unit: 'galao' }).first == 422
ok 'preco negativo: 422', api.(:post, 'items', { name: 'X', price: '-1' }).first == 422
cat_alheia = outra.commerce_categories.create!(name: 'Alheia')
ok 'categoria de outra conta: 404', api.(:post, 'items', { name: 'X', category_id: cat_alheia.id }).first == 404

ok 'filtro por tipo', api.(:get, 'items?kind=service')[1]['payload'].map { |i| i['id'] } == [servico['id']]
ok 'busca por codigo', api.(:get, 'items?q=tr-1')[1]['payload'].map { |i| i['id'] } == [produto['id']]
ok 'filtro por categoria', api.(:get, "items?category_id=#{cat['id']}")[1]['payload'].map { |i| i['id'] } == [servico['id']]

png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: 'foto.png', content_type: 'image/png')
st, com_foto = api.(:post, "items/#{produto['id']}/images", { blob_id: blob.signed_id })
ok 'imagem anexada, com url', st == 200 && com_foto['images'].size == 1 && com_foto['images'][0]['url'].include?('foto.png')
ok 'blob invalido: 400', api.(:post, "items/#{produto['id']}/images", { blob_id: 'lixo' }).first == 400
st, sem_foto = api.(:delete, "items/#{produto['id']}/images/#{com_foto['images'][0]['id']}")
ok 'imagem removida', st == 200 && sem_foto['images'].empty?

ok 'agente consulta o catalogo', api.(:get, 'items', user: beto).first == 200
ok 'agente nao cria item: 401', api.(:post, 'items', { name: 'X' }, user: beto).first == 401
ok 'agente nao apaga categoria: 401', api.(:delete, "categories/#{cat['id']}", user: beto).first == 401

api.(:delete, "categories/#{cat['id']}")
ok 'categoria apagada: o item fica sem categoria', Commerce::Item.find(servico['id']).category_id.nil?

st, perfil = api.(:get, 'profile')
ok 'empresa nasce na primeira leitura', st == 200 && perfil['default_currency'] == 'USD' && perfil['logo_url'].nil?
logo = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: 'logo.png', content_type: 'image/png')
_, perfil = api.(:patch, 'profile', { trade_name: 'Loja Bonita', tax_id_label: 'RUC', tax_id: '123-4', default_currency: 'EUR',
                                      logo_blob_id: logo.signed_id })
ok 'empresa grava dados e logo', perfil['trade_name'] == 'Loja Bonita' && perfil['default_currency'] == 'EUR' && perfil['logo_url'].present?
_, perfil = api.(:patch, 'profile', { remove_logo: true })
ok 'remove o logo', perfil['logo_url'].nil? && Commerce::Profile.where(account: account).count == 1
ok 'agente nao altera a empresa: 401', api.(:patch, 'profile', { trade_name: 'X' }, user: beto).first == 401

_, pix = api.(:post, 'payment_methods', { name: 'Pix', kind: 'pix', instructions: 'Chave: loja@bonita.test' })
_, metodos = api.(:get, 'payment_methods')
ok 'forma de pagamento com instrucoes', pix['kind'] == 'pix' && metodos['payload'].map { |m| m['id'] } == [pix['id']]
ok 'tipo de pagamento invalido: 422', api.(:post, 'payment_methods', { name: 'X', kind: 'bitcoin' }).first == 422
ok 'apaga item', api.(:delete, "items/#{produto['id']}").first == 200 && !Commerce::Item.exists?(produto['id'])
