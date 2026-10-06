# Stripe com a chave secreta da própria conta: Checkout Session hospedada para
# pagar a fatura, e o webhook que confirma. O webhook é criado pela API ao
# conectar e o segredo dele fica guardado (cifrado) no provedor.
class Commerce::Gateways::Stripe
  EVENTS = %w[checkout.session.completed checkout.session.async_payment_succeeded
              checkout.session.async_payment_failed checkout.session.expired].freeze
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

  def start!(checkout, return_url:)
    document = checkout.document
    session = call do
      client.v1.checkout.sessions.create(session_params(checkout, document, return_url), { idempotency_key: "cortexgen-checkout-#{checkout.id}" })
    end
    checkout.update!(external_id: session.id, checkout_url: session.url)
  end

  def status(checkout)
    result(call { client.v1.checkout.sessions.retrieve(checkout.external_id) })
  end

  # [{ external_id: sessão }, resultado] dos eventos de checkout; nil para os
  # outros.
  def webhook(http_request)
    event = ::Stripe::Webhook.construct_event(http_request.raw_post, http_request.headers['Stripe-Signature'].to_s,
                                              @provider.webhook_secret.to_s)
    return unless EVENTS.include?(event.type)

    session = event.data.object
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
