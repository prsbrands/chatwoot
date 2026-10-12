# Conta de demonstração da Evolução da IA ("Demo Evolução"), com conversas
# sintéticas: não há dados reais até a liberação final do sistema.
#
#   docker cp ops/demo/evolucao_seed.rb $(docker compose ps -q rails):/tmp/
#   docker compose exec -T -e ADMIN_EMAIL=<seu e-mail> rails bundle exec rails runner /tmp/evolucao_seed.rb
#   (APAGAR=1 no lugar de ADMIN_EMAIL apaga a conta e o que ela tem no Supabase)
#
# Cria a conta (flags ai_evolution e cases), põe o admin indicado nela, uma
# caixa de API, uma persona com o modelo da persona da conta 1, três documentos
# de base, a rota e o chat_user_token no Supabase, e 14 conversas dos últimos
# dias com os sinais que a rodada lê:
#   - envio para outras províncias (5 conversas, a equipe responde o preço): uma
#     proposta de base com várias evidências;
#   - instalação (3 conversas): outra proposta de base;
#   - garantia (2 conversas, a equipe corrige a base): uma correção;
#   - desconto prometido pela IA e retido pelo Jev: regra de prompt;
#   - produto quebrado, caso aberto pela IA, a equipe responde pelo assistente;
#   - pedido específico e passagem sem resposta: não devem gerar nada.
# O bot é ligado à caixa no fim, para as mensagens semeadas não dispararem o bot.
#
# Script de operação, rodado à mão: escreve no terminal, para no APAGAR e data
# as mensagens no passado sem passar pelos callbacks (que disparariam o bot).
# rubocop:disable Rails/Output, Rails/Exit, Rails/SkipsModelValidations
NOME = 'Demo Evolução'.freeze
client = Integrations::Botlayer::Client.new

if ENV['APAGAR'] == '1'
  account = Account.find_by!(name: NOME)
  client.routes(account.id).each { |route| client.delete_route(route['id']) }
  client.knowledge_docs(account.id).each { |doc| client.delete_knowledge_doc(account.id, doc['id']) }
  client.personas(account.id).each { |persona| client.delete_persona(account.id, persona['id']) }
  AccountDeletionService.new(account: account).perform
  puts "Conta #{account.id} apagada."
  exit
end

abort "A conta #{NOME} já existe (id #{Account.find_by(name: NOME).id}). Use APAGAR=1 antes." if Account.exists?(name: NOME)
admin = User.find_by!(email: ENV.fetch('ADMIN_EMAIL'))
modelo = client.resolved_persona(1, 'nathan-whatsapp') || abort('persona nathan-whatsapp da conta 1 não encontrada')

account = Account.create!(name: NOME, locale: 'es')
account.enable_features!('ai_evolution', 'cases', 'sales_pipeline')
AccountUser.create!(account: account, user: admin, role: :administrator)
equipe = User.find_or_create_by!(email: 'laura.demo@cortexgen.invalid') do |user|
  user.name = 'Laura (equipo)'
  user.password = "Demo-#{SecureRandom.hex(16)}!"
  user.confirmed_at = Time.current
end
AccountUser.create!(account: account, user: equipe, role: :agent)
inbox = account.inboxes.create!(name: 'WhatsApp Demo', channel: Channel::Api.create!(account: account))
bot = AgentBot.create!(name: 'CortexGen Demo', account: account, outgoing_url: 'https://demo.cortexgen.invalid/hook')

persona = client.create_persona(account.id, {
                                  slug: 'asistente-demo', display_name: 'Sofía', is_active: true,
                                  provider: modelo['provider'] || 'openrouter', model: modelo['model'],
                                  light_model: modelo['light_model'], temperature: 0.4, max_tokens: 800,
                                  system_prompt: "Eres Sofía, asistente de Cortinas del Istmo, tienda de cortinas y persianas en Panamá.\n" \
                                                 'Responde corto, amable y en el idioma del cliente. ' \
                                                 'Usa solo la base de conocimiento para precios y plazos.'
                                })
docs = [
  ['horarios', 'Horario y contacto',
   "### Horario\nLunes a sábado de 9:00 a 18:00. Domingo cerrado.\n\n### Dirección\nVía España, Ciudad de Panamá."],
  ['precios', 'Precios',
   "### Cortina blackout\nUSD 35,50 por m2.\n\n### Persiana enrollable\nUSD 42 por m2.\n\n### Formas de pago\nTarjeta, Yappy y transferencia."],
  ['entregas', 'Entregas y garantía',
   "### Entregas\nEntregamos en Ciudad de Panamá en 5 días hábiles, sin costo.\n\n### Garantía\nGarantía de 6 meses contra defectos de fábrica."]
].map do |slug, title, content|
  doc = client.create_knowledge_doc(account.id, { slug: slug, title: title, content: content, priority: 100, is_global: false, is_active: true })
  client.set_doc_personas(account.id, doc['id'], [persona['id']])
  doc
end
client.upsert_route({ chatwoot_account_id: account.id, chatwoot_inbox_id: inbox.id, persona_id: persona['id'], is_active: true,
                      channel_label: inbox.name, chatwoot_agent_bot_id: bot.id,
                      chatwoot_agent_bot_secret: bot.secret, chatwoot_agent_bot_access_token: bot.access_token.token })
client.upsert_account_settings(account.id, chat_user_token: admin.access_token.token)

# Cada conversa: [cliente, [[quem, texto], ...], dias atrás]. quem: :c cliente,
# :a assistente (bot), :p passagem (nota), :r passagem com rascunho retido, :t equipe.
NOTA = "Traspaso · Por qué el bot traspasó: el cliente pidió una persona\n\nQué quiere el cliente (resumen de la IA, verifícalo): %s".freeze
RETIDA = "Traspaso · Por qué el bot traspasó: Jev retuvo la respuesta del bot (Jev): promises something only a person can confirm\n\n" \
         "Borrador retenido (envíalo tal cual o reescríbelo):\n\n%s".freeze
CONVERSAS = [
  ['Ana Pérez', [[:c, '¿Hacen envíos a Colón?'], [:a, 'Déjame consultarlo con el equipo.'], [:p, 'saber si envían a Colón'],
                 [:t, 'Hola Ana, sí: a Colón enviamos por USD 8 y llega en 3 días hábiles.']], 9],
  ['Luis Gómez', [[:c, 'Vivo en David, Chiriquí. ¿Me lo pueden mandar?'], [:p, 'envío a Chiriquí'],
                  [:t, 'Claro Luis, a Chiriquí el envío cuesta USD 12 y tarda 4 días hábiles.']], 8],
  ['Marta Ríos', [[:c, 'cuanto cuesta el envio a Colon'], [:p, 'costo de envío a Colón'], [:t, 'USD 8, llega en 3 días hábiles.']], 6],
  ['Pedro Sanz', [[:c, '¿Envían al interior? Estoy en Santiago de Veraguas'], [:p, 'envío a Veraguas'],
                  [:t, 'Sí, al interior enviamos por empresa de transporte: Veraguas USD 10, 3 a 4 días hábiles.']], 4],
  ['Carla Vega', [[:c, 'Hola, para Colón cuánto sale el envío?'], [:p, 'envío a Colón'], [:t, 'Son USD 8 y llega en 3 días hábiles.']], 2],
  ['Jorge Lima', [[:c, '¿Ustedes instalan las cortinas?'], [:a, 'Voy a consultarlo.'], [:p, 'instalación'],
                  [:t, 'Sí, instalamos en Ciudad de Panamá por USD 25 por ventana. Fuera de la ciudad no hacemos instalación.']], 7],
  ['Rosa Díaz', [[:c, 'me pueden instalar 3 persianas?'], [:p, 'instalación de persianas'], [:t, 'Claro, USD 25 por ventana, en la ciudad.']], 5],
  ['Iván Mora', [[:c, 'hacen instalacion en Arraijan?'], [:p, 'instalación en Arraiján'],
                 [:t, 'En Arraiján no, solo instalamos dentro de Ciudad de Panamá. Te podemos recomendar un instalador.']], 3],
  ['Elena Cruz', [[:c, '¿Cuánto dura la garantía?'], [:a, 'La garantía es de 6 meses.'], [:c, 'en la tienda me dijeron otra cosa'],
                  [:p, 'duración de la garantía'],
                  [:t, 'Disculpa la confusión: desde este año la garantía es de 1 año contra defectos de fábrica.']], 6],
  ['Tomás Ruiz', [[:c, 'la garantia es de cuanto?'], [:p, 'garantía'], [:t, 'Es de 1 año contra defectos de fábrica.']], 1],
  ['Sara León', [[:c, '¿Tienen descuento si pago al contado?'], [:r, '¡Sí! Te damos 20% de descuento pagando al contado.'],
                 [:t, 'Hola Sara, no manejamos descuentos por pago al contado. Solo 5% pagando por transferencia.']], 5],
  ['Raúl Peña', [[:c, '¿Mi pedido 4512 ya salió?'], [:p, 'estado del pedido 4512'], [:t, 'Raúl, tu pedido 4512 sale mañana en la mañana.']], 3],
  ['Nora Gil', [[:c, 'quiero hablar con una persona'], [:p, 'hablar con una persona']], 2]
].freeze

def mensagem(conversation, quem, texto, bot, equipe)
  account = conversation.account
  base = { account: account, inbox: conversation.inbox, content: texto }
  case quem
  when :c then conversation.messages.create!(base.merge(message_type: :incoming, sender: conversation.contact))
  when :a then conversation.messages.create!(base.merge(message_type: :outgoing, sender: bot))
  when :p then conversation.messages.create!(base.merge(message_type: :outgoing, private: true, sender: bot, content: format(NOTA, texto)))
  when :r then conversation.messages.create!(base.merge(message_type: :outgoing, private: true, sender: bot, content: format(RETIDA, texto)))
  when :t then conversation.messages.create!(base.merge(message_type: :outgoing, sender: equipe))
  end
end

criadas = CONVERSAS.map do |nome, falas, dias|
  contact = account.contacts.create!(name: nome)
  ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conversation = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci, status: :open)
  inicio = dias.days.ago.change(hour: 10)
  falas.each_with_index do |(quem, texto), k|
    mensagem(conversation, quem, texto, bot, equipe).update_columns(created_at: inicio + (k * 7).minutes, updated_at: inicio + (k * 7).minutes)
  end
  conversation.update_columns(last_activity_at: inicio + (falas.size * 7).minutes)
  conversation
end

# Produto quebrado: a IA abriu o caso e a equipe respondeu pelo assistente.
contact = account.contacts.create!(name: 'Gloria Paz')
ci = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
quebrado = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci)
mensagem(quebrado, :c, 'Me llegó la persiana rota, ¿qué hago?', bot, equipe)
problema = Cases::Type.for(account).to_a.second
problema.update!(ai_mode: :continue, ai_instructions: 'El producto llegó dañado, equivocado o dejó de funcionar.')
kase = Cases::CaseFlow.open!(account, { type_id: problema.id, title: 'Me llegó la persiana rota',
                                        description: 'Me llegó la persiana rota, ¿qué hago?', language: 'es' },
                             source: :ai, conversation: quebrado)
Cases::CaseFlow.new(kase, actor: equipe)
               .relay!('Cambiamos sin costo cualquier producto con defecto dentro de 30 días: solo mándanos una foto.', 'answer')
quebrado.messages.update_all(created_at: 3.days.ago, updated_at: 3.days.ago)
quebrado.update_columns(last_activity_at: 3.days.ago)
criadas << quebrado

AgentBotInbox.create!(inbox: inbox, agent_bot: bot, account: account)

puts "Conta #{account.id} (#{NOME}): #{criadas.size} conversas, persona #{persona['id']} (#{modelo['model']}), #{docs.size} documentos de base."
puts 'Agora: Super Admin não precisa de nada; no n8n, abrir "CortexGen Evolução" e "Execute workflow".'
# rubocop:enable Rails/Output, Rails/Exit, Rails/SkipsModelValidations
