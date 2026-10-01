# Bloco 3b contra Postgres/Redis descartaveis. O Jev e o Supabase sao trocados
# por respostas fixas: aqui se testa a regra, nao o modelo.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

$jev_state = 'deciding'
$resposta = nil
$registros = []
Integrations::Botlayer::Client.class_eval do
  define_method(:account_settings) { |_id| { 'jev_api_key' => 'k', 'jev' => { 'enabled' => true, 'consent' => true, 'activities' => { 'deal_stage' => $jev_state } } } }
  define_method(:record_jev_call) { |attrs| $registros << attrs }
end
Captain::JevClient.class_eval do
  define_method(:call) do |body:, decisions: nil|
    $ultimo_body = JSON.parse(body)
    data = { 'answers' => { 'stage' => $resposta }, 'model' => 'jev-test' }
    $registros << { decisions: decisions&.call(data) }
    data
  end
end

account = Account.create!(name: 'Funil 3b', locale: 'pt_BR')
account.enable_features!('sales_pipeline')
pipeline = Sales::Pipeline.default_for(account)
st = pipeline.stages.index_by(&:agent_step)
won = pipeline.stages.won.first
channel = Channel::Api.create!(account: account)
inbox = account.inboxes.create!(name: 'WA', channel: channel)
user = User.create!(name: 'Humana', email: "h#{SecureRandom.hex(3)}@ex.com", password: 'Senha!1234Aa', confirmed_at: Time.current)

def novo(account, inbox, nome)
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci, status: :pending)
  conv.messages.create!(account: account, inbox: inbox, sender: contact, message_type: :incoming, content: 'quero um orçamento')
  [Sales::Deal.open_for_contact!(contact, conversation: conv), conv]
end

deal, conv = novo(account, inbox, 'A')
advisor = Sales::StageAdvisor.new(deal: deal, conversation: conv)
chaves = advisor.send(:criteria).keys
ok 'so etapas a frente + won + stay, sem perda', chaves == ["stage_#{st['contacted'].id}", "stage_#{st['qualifying'].id}", "stage_#{st['qualified'].id}", "stage_#{st['negotiating'].id}", 'won', 'stay']

$resposta = { 'choice' => "stage_#{st['qualified'].id}", 'confidence' => 0.9 }
advisor.perform
deal.reload
ok '90% move sozinho', deal.stage == st['qualified']
ok 'transicao com autor ai e confianca', deal.transitions.first.actor_type == 'ai' && deal.transitions.first.reason == 'Jev 90%'
ok 'transcricao foi ao Jev', $ultimo_body.dig('state', 'conversation', 'messages').any? { |m| m['text'].include?('orçamento') }
ok 'registro conta o sinal', $registros.last[:decisions]['deal_stage'][:signal] == true

$resposta = { 'choice' => "stage_#{st['negotiating'].id}", 'confidence' => 0.6 }
Sales::StageAdvisor.new(deal: deal, conversation: conv).perform
deal.reload
ok '60% so sugere', deal.stage == st['qualified'] && deal.suggested_stage == st['negotiating'] && (deal.suggested_confidence - 0.6).abs < 0.01

deal.move_to!(st['negotiating'], actor: user, reason: 'aceitou sugestao')
ok 'mover limpa a sugestao', deal.reload.suggested_stage_id.nil?

d2, c2 = novo(account, inbox, 'B')
$resposta = { 'choice' => 'won', 'confidence' => 0.95 }
Sales::StageAdvisor.new(deal: d2, conversation: c2).perform
d2.reload
ok 'fechou com 95% e so sugestao', d2.open? && d2.suggested_stage == won

$resposta = { 'choice' => 'stay', 'confidence' => 0.99 }
d3, c3 = novo(account, inbox, 'C')
Sales::StageAdvisor.new(deal: d3, conversation: c3).perform
ok 'stay nao faz nada', d3.reload.stage == st['new'] && d3.suggested_stage_id.nil?

$jev_state = 'observing'
$resposta = { 'choice' => "stage_#{st['qualifying'].id}", 'confidence' => 0.95 }
Sales::StageAdvisor.new(deal: d3, conversation: c3).perform
ok 'observing so registra', d3.reload.stage == st['new'] && d3.suggested_stage_id.nil? && $registros.last[:decisions]['deal_stage'][:acted] == false
$jev_state = 'deciding'

d4, c4 = novo(account, inbox, 'D')
d4.move_to!(st['contacted'], actor: user)
$resposta = { 'choice' => "stage_#{st['qualifying'].id}", 'confidence' => 0.95 }
Sales::StageAdvisor.new(deal: d4, conversation: c4).perform
d4.reload
ok 'humano mexeu ha pouco: so sugere', d4.stage == st['contacted'] && d4.suggested_stage == st['qualifying']

st['qualifying'].update!(requires_human: true)
d5, c5 = novo(account, inbox, 'E')
Sales::StageAdvisor.new(deal: d5, conversation: c5).perform
ok 'precisa de pessoa: move e abre a conversa', d5.reload.stage == st['qualifying'] && c5.reload.open? &&
                                                c5.messages.activity.last&.content.to_s.include?(st['qualifying'].name)

$jev_state = nil
Integrations::Botlayer::Client.class_eval { define_method(:account_settings) { |_id| {} } }
d6, c6 = novo(account, inbox, 'F')
$resposta = { 'choice' => "stage_#{st['qualifying'].id}", 'confidence' => 0.99 }
Sales::StageAdvisor.new(deal: d6, conversation: c6).perform
ok 'sem Jev ligado nao faz nada', d6.reload.stage == st['new']

# Espera: so a ultima mensagem da rajada avalia.
m1 = c6.messages.create!(account: account, inbox: inbox, sender: d6.contact, message_type: :incoming, content: 'um')
Sales::StageAdvisorJob.schedule(d6, m1)
m2 = c6.messages.create!(account: account, inbox: inbox, sender: d6.contact, message_type: :incoming, content: 'dois')
Sales::StageAdvisorJob.schedule(d6, m2)
ok 'rajada: so a ultima mensagem vale', Redis::Alfred.get(Sales::StageAdvisorJob.key(d6.id)).to_i == m2.id
chamou = false
Sales::StageAdvisor.class_eval { alias_method :perform_original, :perform; define_method(:perform) { chamou = true } }
Sales::StageAdvisorJob.new.perform(d6.id, m1.id)
ok 'job da mensagem antiga nao roda', !chamou
Sales::StageAdvisorJob.new.perform(d6.id, m2.id)
ok 'job da ultima mensagem roda', chamou

d6.suggest!(st['qualified'], 0.7)
d6.dismiss_suggestion!
ok 'descartar limpa', d6.reload.suggested_stage_id.nil?
