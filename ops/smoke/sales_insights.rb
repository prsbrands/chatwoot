# Bloco 3c contra Postgres/Redis descartaveis.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")
F = Sales::ScoreFormula

r = F.compute(facts: { 'asked_proposal' => 0.9, 'need' => 0.8, 'price_objection' => 0.75 }, risk: 'on_track')
ok 'formula: 30+12+5-8+10 = 49 morno', r[:score] == 49 && r[:band] == 'warm' && r[:factors].map { |f| f[:key] }.sort == %w[asked_proposal need price_objection recency_on_track].sort
ok 'formula: 1 sinal = sem score', F.compute(facts: { 'need' => 0.9 }, risk: 'on_track')[:score].nil?
ok 'formula: abaixo de 0,7 nao conta', F.compute(facts: { 'need' => 0.69, 'budget' => 0.69 }, risk: 'on_track')[:score].nil?
top = F.compute(facts: %w[next_step asked_proposal buying_intent need budget timeline authority].index_with { 0.9 }, risk: 'on_track')
ok 'formula: tudo positivo = 96 quente (teto real)', top[:score] == 96 && top[:band] == 'hot'
low = F.compute(facts: %w[price_objection timing_objection competitor_or_doubt].index_with { 0.9 }, risk: 'critical')
ok 'formula: limite em 0', low[:score] == 0 && low[:band] == 'cold'
ok 'faixa: folga de 5 segura o quente em 67', F.band_for(67, 'hot') == 'hot' && F.band_for(64, 'hot') == 'warm' && F.band_for(72, 'warm') == 'warm' && F.band_for(76, 'warm') == 'hot'
ok 'risco: 10h de 24 em dia, 30h em risco, 72h critico', Sales::DealInsight.risk_for(10, 24) == :on_track && Sales::DealInsight.risk_for(30, 24) == :at_risk && Sales::DealInsight.risk_for(72, 24) == :critical

account = Account.create!(name: 'Funil 3c', locale: 'es')
account.enable_features!('sales_pipeline')
pipeline = Sales::Pipeline.default_for(account)
channel = Channel::Api.create!(account: account)
inbox = account.inboxes.create!(name: 'WA', channel: channel)
def conversa(account, inbox, nome, horas_atras)
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conv = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
  m = conv.messages.create!(account: account, inbox: inbox, sender: contact, message_type: :incoming, content: 'quiero precio')
  m.update_columns(created_at: horas_atras.hours.ago)
  [Sales::Deal.open_for_contact!(contact, conversation: conv), conv]
end
d1, = conversa(account, inbox, 'Em dia', 2)
d2, c2 = conversa(account, inbox, 'Em risco', 30)
d3, = conversa(account, inbox, 'Critico', 100)
# Nota privada e atividade recentes nao zeram o relogio.
c2.messages.create!(account: account, inbox: inbox, message_type: :outgoing, private: true, content: 'nota interna')
c2.messages.create!(account: account, inbox: inbox, message_type: :activity, content: 'Conversation was marked pending')
antes = d2.reload.updated_at

Sales::RiskSweepJob.perform_now
ok 'radar: em dia', d1.reload.insight.on_track?
ok 'radar: em risco (nota e atividade nao contam)', d2.reload.insight.at_risk? && d2.insight.risk_since.present?
ok 'radar: critico', d3.reload.insight.critical?
ok 'varredura nao toca no negocio', d2.reload.updated_at == antes
carimbo = d2.insight.updated_at
Sales::RiskSweepJob.perform_now
ok 'nada mudou: nao regrava', d2.reload.insight.updated_at == carimbo
ok 'etapa com 200h esperadas: 100h volta a em dia', begin
  d3.stage.update!(expected_duration_hours: 200); Sales::RiskSweepJob.perform_now; d3.reload.insight.on_track?
end

# O Jev grava os sinais e o score sai da formula.
Integrations::Botlayer::Client.class_eval do
  define_method(:account_settings) { |_id| { 'jev_api_key' => 'k', 'jev' => { 'enabled' => true, 'consent' => true, 'activities' => { 'deal_stage' => 'observing' } } } }
  define_method(:record_jev_call) { |_attrs| nil }
end
Captain::JevClient.class_eval do
  define_method(:call) do |body:, decisions: nil|
    perguntas = JSON.parse(body)['questions'].keys
    $perguntas = perguntas
    answers = { 'asked_proposal' => { 'noul' => 0.92 }, 'budget' => { 'noul' => 0.8 }, 'timeline' => { 'noul' => 0.71 }, 'price_objection' => { 'noul' => 0.2 } }
    answers['stage'] = { 'choice' => 'stay', 'confidence' => 0.9 } if perguntas.include?('stage')
    data = { 'answers' => answers }
    decisions&.call(data)
    data
  end
end
Sales::StageAdvisor.new(deal: d2, conversation: c2).perform
i2 = d2.reload.insight
ok 'Jev recebe os 10 sinais e a etapa', ($perguntas - ['stage']).size == 10 && $perguntas.include?('stage')
ok 'sinais gravados com a mensagem', i2.facts['asked_proposal'] == 0.92 && i2.facts_message_id.present?
ok 'score: 30+12+5+5-10 = 42 morno', i2.score == 42 && i2.score_band == 'warm'
ok 'negocio continua intocado', d2.updated_at == antes
ok 'JSON traz insight', ApplicationController.render(template: 'api/v1/accounts/sales/deals/show', formats: [:json], assigns: { deal: d2 }).include?('"score":42')
