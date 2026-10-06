# Stripe com a chave secreta da própria conta: Checkout Session hospedada para
# pagar a fatura ou assinar um plano (Stripe Billing cobra os ciclos), e o
# webhook que confirma. O webhook é criado pela API ao conectar e o segredo
# dele fica guardado (cifrado) no provedor.
class Commerce::Gateways::Stripe
  CHECKOUT_EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded
                       checkout.session.async_payment_failed checkout.session.expired].freeze
  SUBSCRIPTION_EVENTS = %w[invoice.paid invoice.payment_failed customer.subscription.deleted].freeze
  EVENTS = CHECKOUT_EVENTS + SUBSCRIPTION_EVENTS
  LOCALES = { 'es' => 'es', 'pt' => 'pt-BR', 'en' => 'en' }.freeze
  # A Stripe aceita sessões de 30 min a 24 h; a conciliação expira a tentativa
  # depois de Commerce::Checkout::EXPIRES_IN.
  SESSION_TTL = 23.hours

  def initialize(provider)
    @provider = provider
  end

  # Valida a chave criando o webhook da conta; trocar a chave cria outro e
  # apaga o anterior.
  def connect!
    key = @provider.credential(:secret_key).to_s
    unless key.match?(@provider.sandbox? ? /\A[rs]k_test_/ : /\A[rs]k_live_/)
      fail_with("The secret key does not match the #{@provider.environment} environment")
    end

    previous = @provider.webhook_endpoint_id
    endpoint = call { client.v1.webhook_endpoints.create(url: @provider.webhook_url, enabled_events: EVENTS, description: 'CortexGen Chat') }
    @provider.assign_attributes(webhook_endpoint_id: endpoint.id, webhook_secret: endpoint.secret)
    remove_endpoint(previous) if previous.present?
  rescue Commerce::Gateways::Error => e
    fail_with(e.message)
  end

  def start!(checkout, return_url:, **)
    document = checkout.document
    session = call do
      client.v1.checkout.sessions.create(session_params(checkout, document, return_url), { idempotency_key: "cortexgen-checkout-#{checkout.id}" })
    end
    checkout.update!(external_id: session.id, checkout_url: session.url)
  end

  def status(checkout)
    result(call { client.v1.checkout.sessions.retrieve(checkout.external_id) })
  end

  # O webhook das contas conectadas antes das assinaturas só tinha os eventos de
  # checkout: a primeira assinatura acrescenta os do Stripe Billing.
  def start_subscription!(subscription, return_url:, **)
    call { client.v1.webhook_endpoints.update(@provider.webhook_endpoint_id, enabled_events: EVENTS) }
    call { client.v1.checkout.sessions.create(subscription_session_params(subscription, return_url)) }.url
  end

  def cancel_subscription!(subscription, at_period_end:)
    call do
      if at_period_end
        client.v1.subscriptions.update(subscription.external_id, cancel_at_period_end: true)
      else
        client.v1.subscriptions.cancel(subscription.external_id)
      end
    end
  end

  # [{ external_id: sessão }, resultado] dos eventos de checkout de fatura; os
  # de assinatura são aplicados aqui (Commerce::SubscriptionBilling) e devolvem
  # nil, como os outros.
  def webhook(http_request)
    event = ::Stripe::Webhook.construct_event(http_request.raw_post, http_request.headers['Stripe-Signature'].to_s,
                                              @provider.webhook_secret.to_s)
    return subscription_event(event) if SUBSCRIPTION_EVENTS.include?(event.type)
    return unless CHECKOUT_EVENTS.include?(event.type)

    session = event.data.object
    return link_subscription(session) if session.mode == 'subscription'

    [{ external_id: session.id }, event.type == 'checkout.session.async_payment_failed' ? { status: :failed } : result(session)]
  rescue ::Stripe::SignatureVerificationError, JSON::ParserError
    raise Commerce::Gateways::InvalidSignature
  end

  private

  def client
    @client ||= ::Stripe::StripeClient.new(@provider.credential(:secret_key))
  end

  def call
    yield
  rescue ::Stripe::StripeError => e
    Rails.logger.warn("[COMMERCE] Stripe (provider #{@provider.id}): #{e.message}")
    raise Commerce::Gateways::Error, e.message
  end

  def session_params(checkout, document, return_url)
    labels = Commerce::DocumentLabels.for(document.language)
    {
      mode: 'payment',
      line_items: [{ quantity: 1, price_data: { currency: checkout.currency.downcase, unit_amount: (checkout.amount * 100).to_i,
                                                product_data: { name: "#{labels[:invoice]} #{document.number}" } } }],
      client_reference_id: checkout.id.to_s,
      metadata: { checkout_id: checkout.id, document: document.number },
      customer_email: document.customer['email'].to_s.match?(URI::MailTo::EMAIL_REGEXP) ? document.customer['email'] : nil,
      locale: LOCALES.fetch(document.language),
      success_url: "#{return_url}?checkout=#{checkout.id}",
      cancel_url: return_url,
      expires_at: SESSION_TTL.from_now.to_i
    }.compact
  end

  # O plano vai como preço avulso (price_data), sem catálogo no Stripe; a
  # quantidade já entra no valor, porque a nossa pode ser fracionária.
  def subscription_session_params(subscription, return_url)
    email = subscription.customer['email'].to_s
    {
      mode: 'subscription',
      line_items: [{ quantity: 1, price_data: { currency: subscription.currency.downcase, unit_amount: (subscription.amount * 100).to_i,
                                                recurring: { interval: subscription.interval }, product_data: { name: subscription.name } } }],
      client_reference_id: "subscription-#{subscription.id}",
      subscription_data: { metadata: { cortexgen_subscription_id: subscription.id } },
      customer_email: email.match?(URI::MailTo::EMAIL_REGEXP) ? email : nil,
      locale: LOCALES.fetch(subscription.language),
      success_url: "#{return_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: return_url
    }.compact
  end

  def link_subscription(session)
    return unless session.status == 'complete' && session.subscription.present?

    subscription = find_subscription(session.subscription)
    Commerce::SubscriptionBilling.new(subscription).link!(session.subscription) if subscription
    nil
  end

  # A fatura do ciclo traz o id da assinatura em parent (versões novas da API)
  # ou na raiz (antigas): o webhook usa a versão padrão da conta Stripe.
  def subscription_event(event)
    object = event.data.object.to_hash
    stripe_id = event.type == 'customer.subscription.deleted' ? object[:id] : invoice_subscription_id(object)
    subscription = stripe_id.present? && find_subscription(stripe_id)
    return unless subscription

    billing = Commerce::SubscriptionBilling.new(subscription)
    case event.type
    when 'invoice.paid' then cycle_paid(billing, object)
    when 'invoice.payment_failed' then billing.payment_failed!
    else billing.ended!
    end
    nil
  end

  def invoice_subscription_id(invoice)
    invoice.dig(:parent, :subscription_details, :subscription) || invoice[:subscription]
  end

  def cycle_paid(billing, invoice)
    return unless invoice[:amount_paid].to_i.positive?

    period = invoice.dig(:lines, :data, 0, :period) || { start: invoice[:period_start], end: invoice[:period_end] }
    billing.cycle_paid!(external_id: invoice[:id], amount: BigDecimal(invoice[:amount_paid].to_s) / 100,
                        period_start: Time.zone.at(period[:start]).to_date, period_end: Time.zone.at(period[:end]).to_date)
  end

  # Pelo id do Stripe; o primeiro aviso pode chegar antes do checkout.session
  # que o liga, então o metadata da assinatura no Stripe diz qual é a nossa.
  def find_subscription(stripe_id)
    @provider.subscriptions.find_by(external_id: stripe_id) || begin
      remote = call { client.v1.subscriptions.retrieve(stripe_id) }
      @provider.subscriptions.find_by(id: remote.metadata.to_hash[:cortexgen_subscription_id])&.tap do |subscription|
        Commerce::SubscriptionBilling.new(subscription).link!(stripe_id)
      end
    end
  end

  def result(session)
    status = if %w[paid no_payment_required].include?(session.payment_status)
               :paid
             elsif session.status == 'expired'
               :expired
             else
               :pending
             end
    { status: status, amount: BigDecimal(session.amount_total.to_s) / 100, reference: session.payment_intent }
  end

  # O webhook antigo pode ser de outra conta Stripe (chave trocada): sumir com
  # ele é bom, mas não pode impedir a conexão nova.
  def remove_endpoint(id)
    client.v1.webhook_endpoints.delete(id)
  rescue ::Stripe::StripeError => e
    Rails.logger.info("[COMMERCE] old Stripe webhook #{id} left behind: #{e.message}")
  end

  def fail_with(message)
    @provider.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, @provider
  end
end
