# Tudo o que muda um caso passa por aqui, para o histórico (Cases::Event) ficar
# completo: abrir, editar (tipo, responsável, prioridade, prazo, campos),
# mudar a situação, anotar e ligar conversas. Quem recebe o caso de outra
# pessoa é mencionado numa nota da conversa do caso (vira notificação no sino);
# caso sem conversa fica só no "meus casos".
class Cases::CaseFlow
  EDITABLE = %w[title description type_id priority assignee_id team_id due_at deal_id field_values].freeze
  TRACKED = { 'type_id' => :type_changed, 'assignee_id' => :assigned, 'priority' => :priority_changed, 'due_at' => :due_changed }.freeze
  TRANSITIONS = {
    'start' => [%w[open waiting_customer], 'in_progress'],
    'wait_customer' => [%w[open in_progress], 'waiting_customer'],
    'resolve' => [Cases::Case::ACTIVE, 'resolved'],
    'cancel' => [Cases::Case::ACTIVE, 'canceled'],
    'reopen' => [%w[resolved canceled], 'in_progress']
  }.freeze

  attr_reader :kase

  def initialize(kase, actor: nil, actor_kind: :user)
    @kase = kase
    @actor = actor
    @actor_kind = actor_kind
  end

  # O caso nasce com os padrões do tipo (prioridade e responsável) e, vindo de
  # uma conversa, ligado a ela, com o contato e o negócio aberto dele.
  # Aberto pela IA (`source: :ai`), o histórico registra a IA como autora.
  def self.open!(account, attributes, actor: nil, source: :manual, conversation: nil)
    actor_kind = source.to_s == 'ai' ? :ai : :user
    attributes = attributes.to_h.symbolize_keys
    type = account.cases_types.find_by(id: attributes[:type_id])
    contact = account.contacts.find_by(id: attributes[:contact_id] || conversation&.contact_id)
    defaults = { priority: type&.default_priority, assignee_id: type&.default_assignee_id, team_id: type&.default_team_id,
                 deal_id: contact && open_deal_id(account, contact) }.compact
    kase = account.cases.new(attributes.with_defaults(defaults).merge(type: type, contact: contact, source: source,
                                                                      created_by: (actor if actor_kind.to_s == 'user')))
    new(kase, actor: actor, actor_kind: actor_kind).send(:create!, conversation)
  end

  def self.open_deal_id(account, contact)
    account.sales_deals.open.where(contact_id: contact.id).order(updated_at: :desc).pick(:id)
  end

  def update!(attributes)
    attributes = attributes.to_h.stringify_keys.slice(*EDITABLE)
    attributes['field_values'] = kase.field_values.merge(attributes['field_values'].to_h.stringify_keys) if attributes.key?('field_values')
    Cases::Case.transaction do
      kase.assign_attributes(attributes)
      changes = kase.changes_to_save
      kase.save!
      record_changes!(changes)
    end
    notify_assignee if kase.saved_change_to_assignee_id?
    kase
  end

  def transition!(action, outcome: nil, resolution: nil)
    to = allowed_target!(action)
    Cases::Case.transaction do
      previous = kase.status
      kase.assign_attributes(transition_attributes(to, outcome, resolution))
      resume_due_at
      kase.paused_at = Time.current if to == 'waiting_customer'
      kase.save!
      event!(:status_changed, body: kase.resolution.presence, metadata: { from: previous, to: to, outcome: kase.outcome }.compact)
    end
    kase
  end

  def note!(body)
    event!(:note, body: body)
  end

  def link_conversation!(conversation, origin: false)
    raise ActiveRecord::RecordNotFound unless conversation.contact_id == kase.contact_id

    link = kase.case_conversations.find_or_create_by!(conversation: conversation) do |new_link|
      new_link.account = kase.account
      new_link.origin = origin
    end
    event!(:conversation_linked, metadata: { conversation_id: conversation.display_id }) if link.previously_new_record? && !origin
    link
  end

  private

  def create!(conversation)
    Cases::Case.transaction do
      kase.save!
      event!(:created, metadata: { source: kase.source, conversation_id: conversation&.display_id }.compact)
      link_conversation!(conversation, origin: true) if conversation
    end
    notify_assignee
    kase
  end

  def allowed_target!(action)
    from, to = TRANSITIONS.fetch(action)
    refuse!("#{kase.number} is #{kase.status}: #{action} not allowed") unless from.include?(kase.status)
    missing = action == 'resolve' ? kase.missing_required_fields : []
    refuse!("required fields missing: #{missing.pluck('label').join(', ')}") if missing.any?
    to
  end

  def transition_attributes(to, outcome, resolution)
    case to
    when 'resolved' then { status: to, outcome: outcome.presence || :solved, resolution: resolution, resolved_at: Time.current,
                           resolved_by: (@actor if @actor_kind.to_s == 'user'), canceled_at: nil }
    when 'canceled' then { status: to, resolution: resolution, canceled_at: Time.current }
    when 'in_progress' then { status: to, outcome: nil, resolved_at: nil, resolved_by: nil, canceled_at: nil }
    else { status: to }
    end
  end

  # Ao sair de "esperando o cliente", o prazo anda o tempo que ficou parado.
  def resume_due_at
    return unless kase.paused_at

    kase.due_at += (Time.current - kase.paused_at) if kase.due_at
    kase.paused_at = nil
  end

  def record_changes!(changes)
    TRACKED.each do |attribute, kind|
      next unless changes.key?(attribute)

      from, to = changes[attribute]
      event!(kind, metadata: { from: from, to: to })
    end
    return unless changes.key?('field_values')

    from, to = changes['field_values']
    keys = (from.to_h.keys | to.to_h.keys).reject { |key| from.to_h[key] == to.to_h[key] }
    event!(:field_changed, metadata: { fields: keys.index_with { |key| { from: from.to_h[key], to: to.to_h[key] } } }) if keys.any?
  end

  def event!(kind, body: nil, metadata: {})
    kase.events.create!(account: kase.account, kind: kind, actor_kind: @actor_kind, actor: (@actor if @actor_kind.to_s == 'user'),
                        body: body, metadata: metadata)
  end

  def refuse!(message)
    kase.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, kase
  end

  def notify_assignee
    user = kase.assignee
    conversation = kase.conversations.order('cases_conversations.origin DESC, cases_conversations.created_at DESC').first
    return if user.nil? || user == @actor || conversation.nil?

    content = I18n.t('cases.assigned', mention: mention(user), number: kase.number, title: kase.title,
                                       url: "#{ENV.fetch('FRONTEND_URL')}/app/accounts/#{kase.account_id}/cases/#{kase.id}")
    conversation.messages.create!(account: kase.account, inbox: conversation.inbox, message_type: :outgoing, private: true, content: content)
  end

  def mention(user)
    "[@#{user.available_name}](mention://user/#{user.id}/#{ERB::Util.url_encode(user.available_name)})"
  end
end
