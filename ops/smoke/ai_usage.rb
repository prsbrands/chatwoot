# Uso de IA (GET /integrations/botlayer/ai_usage) e teto mensal no Super Admin
# contra Postgres/Redis descartaveis. O Supabase e falso: o que a RPC
# devolveria vem de USO, e o que seria gravado fica em GRAVADO.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

USO = { 'llm_usd' => 1.5, 'jev_usd' => 0.01, 'month_spend_usd' => 1.51, 'budget_usd' => 10 }.freeze
PEDIDOS = []
GRAVADO = []
Integrations::Botlayer::Client.define_singleton_method(:configured?) { true }
Integrations::Botlayer::Client.class_eval do
  def initialize(*); end

  def ai_usage(account_id, from, to)
    PEDIDOS << { account_id: account_id, from: from, to: to }
    USO
  end

  def account_settings(_account_id) = { 'ai_monthly_budget_usd' => GRAVADO.last&.dig(:ai_monthly_budget_usd) }
  def upsert_account_settings(account_id, attributes) = GRAVADO << attributes.merge(account_id: account_id)
end

account = Account.create!(name: 'Uso', locale: 'es')
account.enable_features!('bot_personas')
ana = User.create!(name: 'Ana', email: "ana-#{SecureRandom.hex(3)}@uso.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: ana, role: :administrator)
beto = User.create!(name: 'Beto', email: "beto-#{SecureRandom.hex(3)}@uso.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: beto, role: :agent)

s = ActionDispatch::Integration::Session.new(Rails.application)
s.host = URI(ENV.fetch('FRONTEND_URL')).host
s.https!
uso = lambda do |user, query = ''|
  s.get("/api/v1/accounts/#{account.id}/integrations/botlayer/ai_usage#{query}", headers: { 'api_access_token' => user.access_token.token })
  [s.response.status, s.response.body.present? ? JSON.parse(s.response.body) : nil]
end

st, corpo = uso.(ana)
ok 'admin le o uso da conta', st == 200 && corpo == USO
ok 'sem intervalo: do comeco do mes ate agora', PEDIDOS.last[:account_id] == account.id &&
                                               PEDIDOS.last[:from] == Time.current.beginning_of_month &&
                                               (Time.current - PEDIDOS.last[:to]).abs < 60
uso.(ana, '?from=2026-08-01T00:00:00Z&to=2026-12-31T00:00:00Z')
ok 'intervalo longo: corta em 93 dias', PEDIDOS.last[:to] == Time.zone.iso8601('2026-08-01T00:00:00Z') + 93.days
ok 'data invalida: 400', uso.(ana, '?from=ontem').first == 400
ok 'agente nao ve: 401', uso.(beto).first == 401
account.disable_features!('bot_personas')
ok 'conta sem a feature: 401', uso.(ana).first == 401
account.enable_features!('bot_personas')

# --- teto no Super Admin -----------------------------------------------------
root = SuperAdmin.create!(name: 'Root', email: "root-#{SecureRandom.hex(3)}@uso.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
s.post '/super_admin/sign_in', params: { super_admin: { email: root.email, password: 'Senha-forte-1!' } }

s.get "/super_admin/accounts/#{account.id}"
pagina = s.response.body
ok 'pagina da conta mostra o gasto e o campo do teto', s.response.status == 200 && pagina.include?('ai_budget[monthly_usd]') &&
                                                      pagina.include?('1.51')
# O token do formulario, como o navegador manda.
token = pagina[%r{action="/super_admin/accounts/#{account.id}/ai_budget".*?name="authenticity_token" value="([^"]+)"}m, 1]
teto = lambda do |valor|
  s.patch "/super_admin/accounts/#{account.id}/ai_budget", params: { authenticity_token: token, ai_budget: { monthly_usd: valor } }
  s.response.status
end

ok 'grava o teto', teto.('25.50') == 302 && GRAVADO.last == { ai_monthly_budget_usd: BigDecimal('25.50'), account_id: account.id }
ok 'em branco: sem teto', teto.('') == 302 && GRAVADO.last[:ai_monthly_budget_usd].nil?
antes = GRAVADO.size
ok 'negativo: 400 e nada gravado', teto.('-1') == 400 && GRAVADO.size == antes
ok 'texto: 400 e nada gravado', teto.('dez') == 400 && GRAVADO.size == antes
