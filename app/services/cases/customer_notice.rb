# Fase 3: avisa o cliente pela conversa do caso quando o tipo pede
# (`notify_customer`): o número ao abrir e um aviso ao resolver. O caso aberto
# pela IA não recebe o aviso de abertura, porque a resposta dela já dá o
# número. Sem conversa, caixa que não entrega (canal API sem webhook) ou fora
# da janela do WhatsApp oficial, o aviso não sai e o histórico diz por quê.
class Cases::CustomerNotice
  def initialize(kase)
    @case = kase
  end

  def opened!
    deliver!(:opened) unless @case.source_ai?
  end

  def resolved!
    deliver!(:resolved)
  end

  private

  def deliver!(notice)
    return unless @case.type.notify_customer

    conversation = @case.main_conversation
    skipped = skip_reason(conversation)
    return record!(notice, skipped: skipped) if skipped

    content = Cases::CustomerLabels.text(notice, @case.customer_language, number: @case.number)
    Messages::MessageBuilder.new(nil, conversation, { message_type: 'outgoing', content: content }).perform
    record!(notice, conversation_id: conversation.display_id)
  end

  def skip_reason(conversation)
    return 'no_conversation' unless conversation
    return 'inbox_does_not_deliver' unless Commerce::DocumentSender.deliverable?(conversation)

    'outside_reply_window' unless conversation.can_reply?
  end

  def record!(notice, **metadata)
    @case.events.create!(account: @case.account, kind: :customer_notified, actor_kind: :system, metadata: { notice: notice }.merge(metadata))
  end
end
