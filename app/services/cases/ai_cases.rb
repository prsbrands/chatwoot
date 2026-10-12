# Fase 2 dos casos: o que o n8n faz com eles, com o token de usuário da conta.
#   - context: os tipos que a IA pode abrir (ai_mode diferente de off) e os
#     casos ativos do cliente, para o MontaPrompt;
#   - open!: a IA abre o caso do tipo que o Jev escolheu. Se o cliente já tem
#     um ativo do mesmo tipo, a mensagem vira nota nele em vez de outro caso;
#   - customer_replied!: o cliente respondeu à pergunta que a equipe mandou
#     pela IA (Cases::CustomerReplyJob, a cada mensagem dele); vai para o
#     histórico, com os anexos, o caso volta a andar e a equipe é avisada;
#   - claim_relays / relay_result!: o workflow "CortexGen Caso" reserva as
#     respostas da equipe (Cases::CaseFlow#relay!), a persona escreve e envia,
#     e o resultado volta para cá.
class Cases::AiCases
  RELAY_CLAIM_TTL = 10.minutes
  RECENT_MESSAGES = 8
  # O MontaPrompt agradece a resposta mesmo se o job já a gravou.
  JUST_REPLIED = 3.minutes

  def initialize(account)
    @account = account
  end

  def context(conversation)
    { types: ai_types, open_cases: active_cases(conversation.contact).map { |kase| case_payload(kase) } }
  end

  def open!(conversation, type_id:, title:, description:, language: nil)
    type = @account.cases_types.where(active: true).where.not(ai_mode: :off).find(type_id)
    existing = active_cases(conversation.contact).where(type_id: type.id).last
    return reuse!(existing, conversation, description) if existing

    kase = Cases::CaseFlow.open!(@account, { type_id: type.id, title: title.to_s.truncate(120), description: description, language: language },
                                 source: :ai, conversation: conversation)
    case_payload(kase).merge(reused: false)
  end

  def customer_replied!(message)
    conversation = message.conversation
    active_cases(conversation.contact).select(&:awaiting_customer_info?).map do |kase|
      flow = Cases::CaseFlow.new(kase, actor_kind: :ai)
      metadata = { conversation_id: conversation.display_id, message_id: message.id, attachments: attachments_of(message) }
      flow.log!(:customer_replied, body: reply_body(message), metadata: metadata)
      flow.transition!('start')
      flow.notify_team!('cases.customer_replied', kase.assignee || fallback_recipient(kase))
      case_payload(kase)
    end
  end

  def claim_relays(inbox_ids, limit)
    claimable_relays.each_with_object([]) do |event, claimed|
      break claimed if claimed.size >= limit

      conversation = event.case.main_conversation
      next unless conversation && inbox_ids.include?(conversation.inbox_id)

      event.update!(metadata: event.metadata.merge('relay' => 'claimed', 'claimed_at' => Time.current.iso8601))
      claimed << relay_payload(event, conversation)
    end
  end

  def relay_result!(event_id, sent:, message: nil)
    event = @account.cases_events.team_reply.find(event_id)
    event.update!(metadata: event.metadata.merge('relay' => sent ? 'sent' : 'failed', 'message' => message.presence).compact)
    kase = event.case
    flow = Cases::CaseFlow.new(kase, actor_kind: :system)
    if !sent
      flow.notify_team!('cases.relay_failed', event.actor || kase.assignee || fallback_recipient(kase))
    elsif event.metadata['mode'] == 'ask' && %w[open in_progress].include?(kase.status)
      flow.transition!('wait_customer')
    end
    event
  end

  private

  def ai_types
    @account.cases_types.ordered.where(active: true).where.not(ai_mode: :off).map do |type|
      { id: type.id, name: type.name, ai_mode: type.ai_mode, instructions: type.ai_instructions.to_s }
    end
  end

  def active_cases(contact)
    @account.cases.active.where(contact_id: contact.id).includes(:type).order(:created_at)
  end

  def reuse!(kase, conversation, description)
    flow = Cases::CaseFlow.new(kase, actor_kind: :ai)
    flow.link_conversation!(conversation)
    flow.log!(:ai_note, body: description)
    case_payload(kase).merge(reused: true)
  end

  def case_payload(kase)
    { id: kase.id, number: kase.number, title: kase.title, type: kase.type.name, ai_mode: kase.type.ai_mode, status: kase.status,
      awaiting_customer_info: kase.awaiting_customer_info?,
      customer_replied_recently: kase.events.customer_replied.exists?(['created_at > ?', JUST_REPLIED.ago]) }
  end

  def reply_body(message)
    message.content.presence || "📎 #{message.attachments.map(&:file_type).join(', ')}"
  end

  def attachments_of(message)
    message.attachments.map { |attachment| { type: attachment.file_type, url: attachment.file_url, thumb: attachment.thumb_url.presence }.compact }
  end

  def claimable_relays
    stale = RELAY_CLAIM_TTL.ago.iso8601
    @account.cases_events.team_reply
            .where("metadata->>'relay' = 'pending' OR (metadata->>'relay' = 'claimed' AND metadata->>'claimed_at' < ?)", stale)
            .includes(case: :type).order(:id)
  end

  def relay_payload(event, conversation)
    kase = event.case
    { event_id: event.id, case_id: kase.id, number: kase.number, title: kase.title, mode: event.metadata['mode'], text: event.body,
      conversation_id: conversation.display_id, inbox_id: conversation.inbox_id, contact_name: kase.contact.name,
      language: kase.customer_language, messages: recent_messages(conversation) }
  end

  def recent_messages(conversation)
    conversation.messages.where(private: false, message_type: %i[incoming outgoing]).where.not(content: [nil, ''])
                .reorder(created_at: :desc).limit(RECENT_MESSAGES).reverse
                .map { |message| { from: message.incoming? ? 'customer' : 'business', text: message.content.to_s.truncate(600) } }
  end

  def fallback_recipient(kase)
    kase.deal&.assignee || @account.administrators.order(:id).first
  end
end
