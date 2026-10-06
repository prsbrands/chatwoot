# O que acontece com a assinatura no provedor: o cliente assina pelo link, cada
# ciclo cobrado vira uma fatura do período já paga (checkout com o id da cobrança,
# então o mesmo aviso não paga duas vezes) e o recibo sai pelo Commerce::ReceiptJob,
# pelos canais da assinatura. Cobrança recusada deixa a assinatura em atraso;
# a equipe cancela no fim do período ou na hora.
class Commerce::SubscriptionBilling
  def initialize(subscription)
    @subscription = subscription
    @account = subscription.account
  end

  # Abre o pagamento recorrente no provedor e devolve o endereço para o cliente.
  # O Mercado Pago pede o e-mail de quem paga.
  def start!(return_url, payer_email: nil)
    raise Commerce::Gateways::Error, 'subscription is not open' unless @subscription.subscribable?

    @subscription.provider.gateway.start_subscription!(@subscription, return_url: return_url, payer_email: payer_email)
  end

  # O provedor confirmou a assinatura feita pelo link (a última concluída, se o
  # cliente abriu mais de uma).
  def link!(external_id)
    @subscription.update!(external_id: external_id)
  end

  # O aviso repetido acha o checkout do ciclo e o settler não paga de novo.
  def cycle_paid!(external_id:, amount:, period_start:, period_end:)
    checkout = @subscription.with_lock do
      @subscription.provider.checkouts.find_by(external_id: external_id) || begin
        invoice = create_invoice!(amount, period_start, period_end)
        @subscription.update!(current_period_start: period_start, current_period_end: period_end,
                              status: @subscription.canceled? ? :canceled : :active)
        @account.commerce_checkouts.create!(document: invoice, provider: @subscription.provider, amount: amount, external_id: external_id,
                                            payment_method: @subscription.payment_method, currency: @subscription.currency)
      end
    end
    Commerce::CheckoutSettler.new(checkout).apply!(status: :paid, amount: amount, reference: external_id)
  end

  def payment_failed!
    return if @subscription.canceled?

    @subscription.update!(status: :past_due)
    note!(I18n.t('commerce.subscription_payment_failed', subscription: @subscription.name))
  end

  def ended!
    @subscription.update!(status: :canceled, canceled_at: @subscription.canceled_at || Time.current)
  end

  # No fim do período, o provedor avisa quando acabar (ended!). Sem nenhum ciclo
  # pago, não há período a esperar; sem assinatura no provedor, só cancela aqui.
  def cancel!(at_period_end:)
    at_period_end &&= !@subscription.pending?
    @subscription.provider.gateway.cancel_subscription!(@subscription, at_period_end: at_period_end) if @subscription.external_id.present?
    at_period_end ? @subscription.update!(cancel_at_period_end: true) : ended!
  end

  private

  # A linha sai com a quantidade e o preço da assinatura quando o valor cobrado
  # bate; senão, com o valor que o provedor cobrou.
  def create_invoice!(amount, period_start, period_end)
    profile = Commerce::Profile.for(@account)
    invoice = @account.commerce_documents.new(kind: :invoice, issue_date: Date.current, subscription: @subscription,
                                              period_start: period_start, period_end: period_end, terms: profile.default_terms,
                                              footer: profile.footer, payment_method_ids: [@subscription.payment_method_id].compact)
    Commerce::DocumentEditor.new(invoice, invoice_params(amount, period_start, period_end)).save!
    email = @subscription.customer['email'].to_s
    invoice.update!(status: :sent, sent_at: Time.current, delivered_email: email.match?(URI::MailTo::EMAIL_REGEXP) ? email : nil)
    invoice
  end

  def invoice_params(amount, period_start, period_end)
    language = @subscription.language
    exact = amount == @subscription.amount
    {
      language: language, currency: @subscription.currency, tax_mode: 'exclusive', contact_id: @subscription.contact_id,
      deal_id: @subscription.deal_id, conversation_id: @subscription.conversation_id, customer: @subscription.customer,
      items: [{ name: @subscription.name, unit: 'unit', quantity: exact ? @subscription.quantity : 1,
                unit_price: exact ? @subscription.unit_price : amount,
                description: [period_start, period_end].map { |day| Commerce::DocumentLabels.date(day, language) }.join(' – ') }]
    }
  end

  def note!(content)
    conversation = @subscription.conversation
    return unless conversation

    conversation.messages.create!(account: @account, inbox: conversation.inbox, message_type: :outgoing, private: true, content: content)
  end
end
