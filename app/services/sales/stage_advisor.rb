# Bloco 3b: a cada mensagem do cliente, o Jev diz em que etapa do funil o
# negocio esta agora. So olha para FRENTE, so entre etapas com passo do agente
# (agent_step), e nunca para a perda: a IA nao sabe o motivo e nao escolhe.
# - confianca >= 0,8 em `deciding`: move sozinho (autor `ai`);
# - entre 0,5 e 0,8, ou "fechou", ou humano mexeu nas ultimas 24 h: sugere;
# - `observing`: so registra o que faria (o cartao do Jev conta).
# Etapa com requires_human recebendo o negocio pela IA abre a conversa para a
# equipe com uma nota.
class Sales::StageAdvisor
  MODEL = 'jev-latest'.freeze
  ACTIVITY = 'deal_stage'.freeze
  AUTO_MOVE = 0.8
  SUGGEST = 0.5
  HUMAN_GRACE = 24.hours
  STEP_CRITERIA = {
    'new' => 'First contact: the customer just arrived and nothing was discussed yet.',
    'contacted' => 'The conversation started: the business answered and the customer is engaging.',
    'qualifying' => "The business is understanding the customer's need, budget, timing or who decides.",
    'qualified' => 'The customer received a proposal, quote or price for their own case.',
    'negotiating' => 'They are discussing terms, price, objections or the details to close.'
  }.freeze

  pattr_initialize [:deal!, :conversation!]

  def perform
    state = activity_state
    return unless %w[observing deciding].include?(state)

    options = criteria
    return if options.size <= 1

    @state = state
    answer = ask(options)
    act(answer['choice'], answer['confidence'].to_f) if answer
  end

  private

  def forward_stages
    @forward_stages ||= deal.pipeline.stages.open.where.not(agent_step: nil).where('position > ?', deal.stage.position).to_a
  end

  def won_stage
    @won_stage ||= deal.pipeline.stages.won.first
  end

  def criteria
    options = forward_stages.to_h { |stage| ["stage_#{stage.id}", "#{STEP_CRITERIA[stage.agent_step]} (stage \"#{stage.name}\")"] }
    options['won'] = 'The customer clearly confirmed the purchase: they accepted, paid, signed or booked.' if won_stage
    options['stay'] = "Nothing in the conversation moves the deal beyond its current stage \"#{deal.stage.name}\", or it is unclear."
    options
  end

  def ask(options)
    body = Captain::JevClient.request_body(
      model: MODEL,
      state: { conversation: { messages: Captain::ConversationTranscript.new(conversation: conversation).messages } },
      questions: { stage: { type: 'choice', instructions: 'Where is this sales conversation now, from the customer point of view?',
                            criteria: options } }
    )
    Captain::JevClient.new(account_id: deal.account_id, conversation_id: conversation.display_id, feature: ACTIVITY)
                      .call(body: body, decisions: ->(data) { decisions_for(data.dig('answers', 'stage')) })
                      .dig('answers', 'stage')
  rescue Captain::JevClient::HTTPError, Captain::JevClient::NotConfigured
    nil
  end

  def target_for(choice)
    return won_stage if choice == 'won'

    forward_stages.find { |stage| choice == "stage_#{stage.id}" }
  end

  # O que vai para bot_jev_calls: signal = o Jev tiraria o negocio da etapa.
  def decisions_for(answer)
    target = answer && target_for(answer['choice'])
    { ACTIVITY => { state: @state, value: answer&.dig('choice'), confidence: answer&.dig('confidence'),
                    signal: target.present? && answer['confidence'].to_f >= SUGGEST, acted: @state == 'deciding' } }
  end

  def act(choice, confidence)
    target = target_for(choice)
    return if target.nil? || confidence < SUGGEST || @state != 'deciding'

    if target.open? && confidence >= AUTO_MOVE && !deal.recently_moved_by_human?(HUMAN_GRACE)
      deal.move_to!(target, actor: 'ai', reason: "Jev #{(confidence * 100).round}%")
      hand_off(target) if target.requires_human?
    else
      deal.suggest!(target, confidence)
    end
  end

  def hand_off(stage)
    conversation.messages.create!(
      account: conversation.account, inbox: conversation.inbox, message_type: :activity, private: false,
      content: I18n.t('sales.stage_needs_human', stage: stage.name)
    )
    conversation.open!
  end

  def activity_state
    settings = Integrations::Botlayer::Client.new.account_settings(deal.account_id)
    jev = settings['jev'] || {}
    return unless settings['jev_api_key'].present? && jev['enabled'] && jev['consent']

    jev.dig('activities', ACTIVITY) || 'observing'
  end
end
