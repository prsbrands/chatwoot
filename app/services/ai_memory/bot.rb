# O que o n8n usa para manter a memória do cliente:
# - claim: as conversas paradas há 30 min com mensagem nova do cliente desde a
#   última leitura, com o resumo e os fatos atuais (um contato por rodada; a
#   reserva vale 1 h, e um LLM que falhou tenta de novo depois disso);
# - apply!: grava o que o LLM devolveu, sem tocar em fato manual ou fixado;
# - for_conversation: a memória do contato da conversa, para o prompt.
class AiMemory::Bot
  QUIET = 30.minutes
  MAX_AGE = 7.days
  RETRY_AFTER = 1.hour
  MAX_FACTS = 30
  MAX_NEW_FACTS = 10
  MAX_NEW_MESSAGES = 40
  EARLIER_MESSAGES = 6
  PUBLIC_TYPES = %w[incoming outgoing].freeze

  def initialize(account)
    @account = account
  end

  def claim(inbox_ids, limit)
    conversations = pending_conversations(inbox_ids).limit(limit * 3).to_a.uniq(&:contact_id).first(limit)
    conversations.filter_map { |conversation| claim_one(conversation) }
  end

  # changes: contact_id, last_message_id, summary, e opcionais conversation_id
  # (display_id), add [texto], update [{id, text}], remove [id].
  def apply!(changes)
    contact = @account.contacts.find(changes[:contact_id])
    conversation = @account.conversations.find_by(display_id: changes[:conversation_id]) if changes[:conversation_id]
    record = summary_for(contact)
    ActiveRecord::Base.transaction do
      change_facts!(contact, changes[:update], changes[:remove])
      add_facts!(contact, conversation, changes[:add])
      trim!(contact)
      record.update!(body: changes[:summary], last_message_id: [record.last_message_id, changes[:last_message_id].to_i].max,
                     refreshed_at: Time.current, claimed_at: nil)
    end
    record
  end

  def for_conversation(conversation)
    summary = AiMemory::Summary.find_by(contact_id: conversation.contact_id)
    facts = AiMemory::Fact.where(contact_id: conversation.contact_id).order(pinned: :desc, created_at: :desc)
    { summary: summary&.body.to_s, facts: facts.map(&:body) }
  end

  private

  # Mensagem pública do cliente com id acima do que a IA já leu desse contato.
  def pending_conversations(inbox_ids)
    incoming = Message.message_types[:incoming]
    @account.conversations.where(inbox_id: inbox_ids, last_activity_at: MAX_AGE.ago..QUIET.ago)
            .joins('LEFT JOIN ai_memory_summaries s ON s.contact_id = conversations.contact_id')
            .where('s.claimed_at IS NULL OR s.claimed_at < ?', RETRY_AFTER.ago)
            .where('EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = conversations.id AND m.message_type = ? ' \
                   'AND m.private = false AND m.id > COALESCE(s.last_message_id, 0))', incoming)
            .preload(:contact).order(last_activity_at: :desc)
  end

  def claim_one(conversation)
    record = summary_for(conversation.contact)
    fresh, earlier = new_messages(conversation, record.last_message_id)
    return if fresh.empty?

    record.update!(claimed_at: Time.current)
    {
      conversation_id: conversation.display_id, inbox_id: conversation.inbox_id,
      contact_id: conversation.contact_id, contact_name: conversation.contact.name.to_s,
      summary: record.body, last_message_id: fresh.last.id, facts: facts_for_llm(conversation.contact_id),
      earlier: earlier.map { |message| line(message) }, messages: fresh.map { |message| line(message) }
    }
  end

  # As mensagens públicas depois do que a IA já leu e algumas de antes, para contexto.
  def new_messages(conversation, last_read_id)
    public = conversation.messages.where(message_type: PUBLIC_TYPES, private: false).where.not(content: [nil, ''])
    fresh = public.where('messages.id > ?', last_read_id).order(:id).last(MAX_NEW_MESSAGES)
    return [[], []] if fresh.empty?

    [fresh, public.where('messages.id < ?', fresh.first.id).order(id: :desc).limit(EARLIER_MESSAGES).reverse]
  end

  def facts_for_llm(contact_id)
    AiMemory::Fact.where(contact_id: contact_id).ordered.map { |fact| { id: fact.id, text: fact.body, locked: fact.locked? } }
  end

  def line(message)
    { from: message.incoming? ? 'customer' : 'business', text: message.content.to_s.strip.truncate(1000) }
  end

  def summary_for(contact)
    AiMemory::Summary.find_or_create_by!(contact: contact) { |record| record.account = @account }
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def change_facts!(contact, update, remove)
    editable = AiMemory::Fact.where(contact: contact).editable_by_ai
    editable.where(id: Array(remove)).delete_all
    Array(update).each { |change| editable.find_by(id: change[:id])&.update!(body: change[:text].to_s.truncate(AiMemory::Fact::MAX_LENGTH)) }
  end

  def add_facts!(contact, conversation, add)
    known = AiMemory::Fact.where(contact: contact).pluck(:body).map { |body| normalize(body) }
    Array(add).first(MAX_NEW_FACTS).each do |text|
      text = text.to_s.squish.truncate(AiMemory::Fact::MAX_LENGTH)
      next if text.blank? || known.include?(normalize(text))

      known << normalize(text)
      AiMemory::Fact.create!(contact: contact, account: @account, conversation: conversation, body: text, source: :ai)
    end
  end

  # Passou do teto: saem os fatos mais antigos da IA; manual e fixado ficam.
  def trim!(contact)
    excess = AiMemory::Fact.where(contact: contact).count - MAX_FACTS
    return unless excess.positive?

    oldest = AiMemory::Fact.where(contact: contact).editable_by_ai.order(:created_at).limit(excess).pluck(:id)
    AiMemory::Fact.where(id: oldest).delete_all
  end

  def normalize(text)
    I18n.transliterate(text.to_s.downcase).gsub(/[^a-z0-9 ]/, '').squish
  end
end
