# Radar de risco: os negócios abertos que esfriaram, do mais grave para o menos
# (o /app/radar do DeskComm). O risco já vem calculado pelo Sales::RiskSweepJob;
# aqui só se separa quem o bot ainda vai retomar ("em voo") de quem depende de
# alguém da equipe.
#
# "Em voo" espelha as regras do Candidatos do workflow de follow-up
# (ops/n8n/followup_candidatos.js): rota do OpenWA com follow-up na persona,
# conversa pendente com o bot, o bot falou por último, o cliente escreveu nos
# últimos 7 dias e a série desse silêncio ainda tem envio. A hora prevista é a
# última mensagem do bot + as horas da persona; o envio de fato ainda espera a
# janela das 8h às 20h e o teto diário do número.
class Sales::Radar
  SCAN_CAP = 300
  NO_NEXT_STEP_CAP = 50
  MAX_SILENCE_AGE = 7.days
  BUCKETS = %w[critical at_risk in_flight].freeze

  def initialize(account)
    @account = account
  end

  def rows
    @rows ||= deals.map { |deal| row(deal) }
                   .sort_by { |row| [BUCKETS.index(row[:bucket]), row[:last_activity_at] || 0] }
  end

  # Negócio aberto sem próximo passo: nenhuma tarefa pendente e nenhum
  # compromisso por vir, nem no negócio nem no contato. É o único número do
  # Radar cujo alvo é zero; os mais antigos na etapa primeiro.
  def without_next_step
    @account.sales_deals.open
            .where("sales_deals.id NOT IN #{next_step_ids(:deal_id)}")
            .where("sales_deals.contact_id NOT IN #{next_step_ids(:contact_id)}")
            .preload(:contact, :stage, :pipeline, :conversation)
            .order(stage_changed_at: :asc)
            .limit(NO_NEXT_STEP_CAP)
  end

  # Compromissos que já acabaram sem dizerem se o cliente veio (o "presença
  # vencida" do CRM). Os mais antigos primeiro.
  def awaiting_outcome
    @account.agenda_appointments.awaiting_outcome.preload(:contact, :owner, :conversation).order(:ends_at)
  end

  private

  def deals
    @deals ||= @account.sales_deals.open
                       .joins(:insight).merge(Sales::DealInsight.where(risk: %i[at_risk critical]))
                       .preload(:contact, :pipeline, :stage, :assignee, :insight,
                                conversation: [:assignee, :contact, { inbox: [:channel, { agent_bot_inbox: :agent_bot }] }])
                       .order('sales_deal_insights.last_activity_at ASC')
                       .limit(SCAN_CAP)
  end

  def row(deal)
    followup_at = followup_at(deal.conversation)
    {
      deal: deal,
      bucket: followup_at ? 'in_flight' : deal.insight.risk,
      last_activity_at: deal.insight.last_activity_at&.to_i,
      followup_at: followup_at&.to_i,
      owner: owner(deal)
    }
  end

  # Subconsulta gerada pelo próprio ActiveRecord (sem entrada do usuário). O
  # `not nil` importa: um NULL no NOT IN zera a lista inteira (tarefa avulsa
  # não tem contato nem negócio).
  def next_step_ids(column)
    tasks = @account.sales_tasks.pending.where.not(column => nil)
    appointments = @account.agenda_appointments.where(status: %i[pending confirmed]).where(starts_at: Time.current..)
                           .where.not(column => nil)
    "(#{tasks.select(column).to_sql} UNION #{appointments.select(column).to_sql})"
  end

  def owner(deal)
    user = deal.conversation&.assignee || deal.assignee
    return { type: 'user', name: user.available_name } if user

    bot = bot_on(deal.conversation)
    bot ? { type: 'bot', name: bot.name } : { type: 'none' }
  end

  def bot_on(conversation)
    return unless conversation&.pending?

    binding = conversation.inbox.agent_bot_inbox
    binding.agent_bot if binding&.active?
  end

  def followup_at(conversation)
    rule = conversation && followup_rules[conversation.inbox_id]
    return unless rule && waiting_on_bot?(conversation)

    last = last_public_message(conversation)
    return unless last&.outgoing? && series_open?(conversation, rule)

    last.created_at + rule[:hours].hours
  end

  # Uma série por silêncio, ancorada na última mensagem do cliente: esgotada,
  # recusada ou vetada, só volta quando o cliente escrever de novo.
  def series_open?(conversation, rule)
    anchor = conversation.messages.incoming.where(private: false).reorder(created_at: :desc).first
    return false if anchor.nil? || anchor.created_at < MAX_SILENCE_AGE.ago

    series = followup_series[[conversation.display_id, anchor.id]]
    series.nil? || (series['status'] == 'active' && series['attempts'] < rule[:max])
  end

  def waiting_on_bot?(conversation)
    inbox = conversation.inbox
    conversation.pending? && conversation.assignee_id.nil? && !conversation.contact.blocked? &&
      !inbox.channel.try(:reauthorization_required?) && %w[UTC Etc/UTC].exclude?(inbox.timezone)
  end

  def last_public_message(conversation)
    conversation.messages.where(private: false, message_type: %i[incoming outgoing])
                .where.not(content: [nil, '']).reorder(created_at: :desc).first
  end

  # Inboxes do OpenWA (split_replies) cuja persona tem follow-up ligado. Conta
  # sem personas não tem bot, então não tem follow-up.
  def followup_rules
    @followup_rules ||= @account.feature_enabled?('bot_personas') ? load_followup_rules : {}
  end

  def load_followup_rules
    personas = botlayer.personas(@account.id).index_by { |persona| persona['id'] }
    botlayer.routes(@account.id).each_with_object({}) do |route, rules|
      persona = personas[route['persona_id']]
      next unless route['is_active'] && route['split_replies'] && persona && persona['followup_after_hours'].to_f.positive?

      rules[route['chatwoot_inbox_id']] = { hours: persona['followup_after_hours'].to_f, max: persona['max_followups'].to_i }
    end
  end

  def followup_series
    @followup_series ||= begin
      ids = deals.filter_map { |deal| deal.conversation&.display_id if followup_rules.key?(deal.conversation&.inbox_id) }
      botlayer.followups(@account.id, ids).index_by { |series| [series['chatwoot_conversation_id'], series['anchor_message_id']] }
    end
  end

  def botlayer
    @botlayer ||= Integrations::Botlayer::Client.new
  end
end
