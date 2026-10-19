# Manda uma pessoa da campanha e diz quando voltar. Devolve o horário da próxima
# volta, ou nil quando a campanha terminou ou parou (pausada pelo sistema).
#
# O envio é direto pelo gateway do OpenWA, não por mensagem do Chatwoot: o
# adaptador só leva ao WhatsApp a mensagem de uma conversa que o cliente já
# abriu. A pessoa é separada (`sending`) antes de chamar o gateway, e um envio
# que deu erro ou ficou sem resposta nunca é repetido: pode ter saído, e
# mandar duas vezes para quem não conhece o número é pior que perder um.
class Outreach::Dispatcher
  MAX_SKIPS = 50
  FAILURES_TO_PAUSE = 3
  SEND_ERRORS = [Integrations::Openwa::Client::ApiError, Timeout::Error, SystemCallError, SocketError].freeze
  FINISH_RECHECK = 5.minutes

  def initialize(campaign)
    @campaign = campaign
  end

  def run
    wait = Outreach::Pace.new(@campaign).wait
    return wait.until if wait

    recipient = claim
    return finish if recipient.nil?
    return Time.current if recipient == :skipped

    deliver(recipient)
  end

  private

  # A próxima pessoa que pode receber. Quem os vetos tiram agora sai da fila com o
  # motivo (a lista foi classificada horas antes e o mundo mudou).
  def claim
    MAX_SKIPS.times do
      recipient = @campaign.recipients.pending.order(:id).first
      return if recipient.nil?

      recipient.variant = next_variant
      reason = Outreach::Eligibility.new(@campaign, [recipient], at_send: true).reason(recipient)
      return recipient.tap { |item| item.update!(status: :sending) } if reason.nil?

      recipient.update!(status: :excluded, excluded_reason: reason, variant: nil)
    end
    :skipped
  end

  # Alterna as variações pelo que já saiu.
  def next_variant
    @campaign.recipients.where.not(sent_at: nil).count % @campaign.variants.size
  end

  def finish
    return Time.current + FINISH_RECHECK if @campaign.recipients.sending.exists?

    while_running { @campaign.transition_to!(:completed, completed_at: Time.current) }
    nil
  end

  def deliver(recipient)
    session = Integrations::Openwa::Client.new.session_for_inbox(@campaign.account_id, @campaign.inbox_id)
    return fail_and_pause(recipient, 'session_not_found', 'no WhatsApp session for the inbox') if session.nil?

    bubbles = Outreach::Message.new(@campaign, recipient).bubbles
    bubbles.each_with_index do |bubble, index|
      Integrations::Openwa::Client.new.send_text(session, recipient.chat_id, bubble)
      pause_between(bubble) unless index == bubbles.size - 1
    end
    recipient.update!(status: :sent, sent_at: Time.current)
    schedule_after_send
  rescue *SEND_ERRORS => e
    recipient.update!(status: :failed, error: e.message.truncate(500))
    failing? ? pause('send_failures') : schedule_after_send
  end

  # A pausa de "digitando" entre as bolhas: o gateway simula o "digitando"
  # antes de cada texto, e a pessoa leva um tempo para escrever a próxima.
  def pause_between(bubble)
    sleep(rand(2.0..4.0) + (bubble.size * 0.03))
  end

  # O intervalo aleatório; a cada `batch_size` envios, o descanso do lote.
  def schedule_after_send
    pacing = @campaign.pace
    while_running do
      batch = @campaign.batch_sent + 1
      batch, delay = batch >= pacing.batch_size ? [0, pacing.next_batch_pause] : [batch, pacing.next_interval]
      @campaign.update!(batch_sent: batch, next_send_at: Time.current + delay)
    end
    @campaign.next_send_at if @campaign.running?
  end

  def failing?
    last = @campaign.recipients.where(status: [:sent, :replied, :failed, :opted_out]).order(updated_at: :desc).limit(FAILURES_TO_PAUSE).pluck(:status)
    last.size == FAILURES_TO_PAUSE && last.all?('failed')
  end

  def fail_and_pause(recipient, reason, error)
    recipient.update!(status: :failed, error: error)
    pause(reason)
  end

  def pause(reason)
    while_running { @campaign.transition_to!(:paused, paused_at: Time.current, paused_reason: reason) }
    nil
  end

  # Relê a campanha com trava: a equipe pode ter pausado ou cancelado durante o
  # envio, e isso não pode ser desfeito por uma cópia velha.
  def while_running
    @campaign.with_lock { yield if @campaign.running? }
  end
end
