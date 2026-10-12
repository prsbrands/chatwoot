# O que o workflow "CortexGen Evolução" usa, com o token de usuário da conta:
# - claim: as conversas das caixas do bot com sinal novo desde a última
#   leitura, paradas há 2 h (a equipe teve tempo de responder), com o trecho
#   da conversa, a persona, a base dela e as propostas pendentes e recusadas;
# - record!: grava o que o LLM propôs, juntando à proposta pendente igual
#   (`same_as`) e descartando a correção cujo trecho não está mais na base.
#
# Os sinais, todos já existentes: a nota da Passagem (o bot passou a conversa)
# seguida de resposta de uma pessoa da equipe; a mesma nota com o rascunho
# retido pelo Jev; e o caso aberto pela IA que a equipe respondeu ou resolveu.
class AiEvolution::Bot
  QUIET = 2.hours
  MAX_AGE = 14.days
  RETRY_AFTER = 1.hour
  MAX_MESSAGES = 40
  MAX_SUGGESTIONS = 3
  KNOWLEDGE_CHARS = 30_000
  PROMPT_CHARS = 3000
  REJECTED_WINDOW = 90.days
  HANDOFF_NOTE = /\A(Handoff|Passagem|Traspaso) · /.freeze
  HELD_DRAFT = /(Held draft|Rascunho retido|Borrador retenido)[^:]*:\s*/.freeze

  def initialize(account)
    @account = account
  end

  # routes: [{ inbox_id, persona_id }] das caixas com bot (o n8n lê as rotas).
  def claim(routes, limit)
    personas = botlayer.personas(@account.id).index_by { |persona| persona['id'] }
    docs = botlayer.knowledge_docs(@account.id)
    persona_of = routes.to_h { |route| [route[:inbox_id].to_i, route[:persona_id].to_s] }
    candidates(persona_of.keys).filter_map do |conversation|
      persona = personas[persona_of[conversation.inbox_id]]
      next unless persona

      claim_one(conversation, persona, docs)
    end.first(limit)
  end

  # result: conversation_id (display_id), last_message_id, persona_id,
  # persona_name, suggestions [{ kind, title, content, target_doc_id,
  # replace_text, same_as, rationale, customer_quote, team_quote }].
  def record!(result)
    conversation = @account.conversations.find_by!(display_id: result[:conversation_id])
    scan = scan_for(conversation)
    docs = botlayer.knowledge_docs(@account.id).index_by { |doc| doc['id'] }
    saved = Array(result[:suggestions]).first(MAX_SUGGESTIONS).filter_map do |item|
      save_suggestion(item, result, conversation, docs)
    end
    scan.update!(last_message_id: [scan.last_message_id, result[:last_message_id].to_i].max, scanned_at: Time.current, claimed_at: nil)
    saved
  end

  private

  def candidates(inbox_ids)
    @account.conversations.where(inbox_id: inbox_ids, last_activity_at: MAX_AGE.ago..QUIET.ago)
            .joins('LEFT JOIN ai_evolution_scans s ON s.conversation_id = conversations.id')
            .where('s.claimed_at IS NULL OR s.claimed_at < ?', RETRY_AFTER.ago)
            .where("EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = conversations.id AND m.private = true
                    AND m.id > COALESCE(s.last_message_id, 0) AND m.content ~ '^(Handoff|Passagem|Traspaso) · ')
                    OR EXISTS (SELECT 1 FROM cases_conversations cc JOIN cases_cases c ON c.id = cc.case_id
                    WHERE cc.conversation_id = conversations.id AND c.source = 2
                    AND c.updated_at > COALESCE(s.scanned_at, 'epoch'))")
            .preload(:contact, :inbox).order(last_activity_at: :desc).limit(100)
  end

  def claim_one(conversation, persona, docs)
    scan = scan_for(conversation)
    messages = conversation.messages.where('messages.id > ?', scan.last_message_id).order(:id).last(MAX_MESSAGES)
    lessons = ai_cases(conversation, scan)
    signals = signals_in(messages, lessons)
    return if signals.empty?

    scan.update!(claimed_at: Time.current)
    { conversation_id: conversation.display_id, inbox_id: conversation.inbox_id, last_message_id: messages.last&.id || scan.last_message_id,
      signals: signals, transcript: messages.filter_map { |message| line(message) }, cases: lessons }.merge(persona_context(persona, docs))
  end

  def persona_context(persona, docs)
    { persona: { id: persona['id'], name: persona['name'], prompt: persona['system_prompt'].to_s.first(PROMPT_CHARS) },
      knowledge: knowledge_for(persona['id'], docs), suggestions: open_suggestions(persona['id']) }
  end

  # Passagem com resposta de alguém da equipe depois dela; retida quando a nota
  # traz o rascunho; caso aberto pela IA com resposta ou resolução da equipe.
  def signals_in(messages, lessons)
    [handoff_signal(messages), ('ai_case' if lessons.any?)].compact
  end

  def handoff_signal(messages)
    note = messages.find { |message| handoff_note?(message) }
    return unless note && messages.any? { |message| message.id > note.id && team_reply?(message) }

    note.content.match?(HELD_DRAFT) ? 'held_reply' : 'handoff'
  end

  def handoff_note?(message)
    message.private? && message.content.to_s.match?(HANDOFF_NOTE)
  end

  def team_reply?(message)
    message.outgoing? && !message.private? && message.sender_type == 'User' && message.content.present?
  end

  def ai_cases(conversation, scan)
    since = scan.scanned_at || Time.zone.at(0)
    Cases::Case.joins(:case_conversations).where(cases_conversations: { conversation_id: conversation.id })
               .where(account: @account, source: :ai).where('cases_cases.updated_at > ?', since).includes(:type, :events)
               .filter_map { |kase| case_lesson(kase) }
  end

  def case_lesson(kase)
    team = kase.events.select(&:team_reply?).map(&:body)
    return if team.empty? && kase.resolution.blank?

    { number: kase.number, type: kase.type.name, title: kase.title, description: kase.description.to_s.truncate(600),
      team_replies: team, resolution: kase.resolution }
  end

  # A conversa como o LLM a lê: cliente, assistente (o bot) e equipe (uma
  # pessoa). Da nota da Passagem vão só o motivo e o rascunho retido.
  def line(message)
    return handoff_line(message) if message.private?
    return if message.content.blank? || %w[incoming outgoing].exclude?(message.message_type)

    { from: speaker(message), text: message.content.to_s.strip.truncate(1000) }
  end

  def handoff_line(message)
    return unless message.content.to_s.match?(HANDOFF_NOTE)

    draft = message.content.split(HELD_DRAFT, 2).last if message.content.match?(HELD_DRAFT)
    { from: 'system', text: "[handed to the team: #{message.content.lines.first.strip}]#{" Held draft: #{draft.strip}" if draft}" }
  end

  def speaker(message)
    return 'customer' if message.incoming?

    message.sender_type == 'User' ? 'team' : 'assistant'
  end

  # Os documentos ativos que entram no prompt da persona; inteiros até o teto,
  # depois só os títulos das seções.
  def knowledge_for(persona_id, docs)
    used = 0
    docs.select { |doc| doc['is_active'] != false && (doc['is_global'] || linked?(doc, persona_id)) }.map do |doc|
      content = doc['content'].to_s
      used += content.size
      entry = { id: doc['id'], title: doc['title'] }
      used <= KNOWLEDGE_CHARS ? entry.merge(content: content) : entry.merge(sections: content.scan(/^#+ (.+)$/).flatten)
    end
  end

  def linked?(doc, persona_id)
    Array(doc['bot_persona_knowledge']).any? { |link| link['persona_id'] == persona_id }
  end

  def open_suggestions(persona_id)
    scope = @account.ai_evolution_suggestions.where(persona_id: persona_id)
    {
      pending: scope.pending.order(:id).map { |suggestion| { id: suggestion.id, kind: suggestion.kind, title: suggestion.title } },
      rejected: scope.rejected.where(rejected_at: REJECTED_WINDOW.ago..)
                     .map { |suggestion| { title: suggestion.title, reason: suggestion.reject_reason } }
    }
  end

  def save_suggestion(item, result, conversation, docs)
    evidence = evidence_item(item, conversation)
    same = pending_match(item, result)
    return same.tap { |suggestion| suggestion.add_evidence!(evidence) } if same

    doc = docs[item[:target_doc_id].to_s]
    return if item[:kind].to_s == 'knowledge_update' && !replaceable?(item, doc)

    @account.ai_evolution_suggestions.create!(suggestion_attributes(item, result, doc).merge(evidence: [evidence], evidence_count: 1))
  rescue ActiveRecord::RecordInvalid, ArgumentError
    nil
  end

  def pending_match(item, result)
    return if item[:same_as].blank?

    @account.ai_evolution_suggestions.pending.find_by(id: item[:same_as], persona_id: result[:persona_id])
  end

  # A correção só vale com o trecho exato que ainda está no documento.
  def replaceable?(item, doc)
    doc.present? && item[:replace_text].present? && doc['content'].to_s.include?(item[:replace_text].to_s)
  end

  def suggestion_attributes(item, result, doc)
    doc = nil if item[:kind].to_s == 'prompt_rule'
    { kind: item[:kind], persona_id: result[:persona_id], persona_name: result[:persona_name],
      title: item[:title].to_s.squish.truncate(AiEvolution::Suggestion::TITLE_LENGTH),
      content: item[:content].to_s.strip.truncate(AiEvolution::Suggestion::CONTENT_LENGTH),
      target_doc_id: doc&.dig('id'), target_doc_title: doc&.dig('title'), rationale: item[:rationale].to_s.truncate(1000),
      replace_text: item[:kind].to_s == 'knowledge_update' ? item[:replace_text] : nil }
  end

  def evidence_item(item, conversation)
    { conversation_id: conversation.display_id, customer_quote: item[:customer_quote].to_s.truncate(500),
      team_quote: item[:team_quote].to_s.truncate(500), at: Time.current.iso8601 }
  end

  def scan_for(conversation)
    AiEvolution::Scan.find_or_create_by!(conversation: conversation) { |scan| scan.account = @account }
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def botlayer
    @botlayer ||= Integrations::Botlayer::Client.new
  end
end
