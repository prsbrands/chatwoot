# Mercado Pago Brasil com o access token da própria conta: Checkout Pro
# (preferência) para pagar a fatura em BRL, com cartão, Pix, boleto ou saldo.
# O aviso do Mercado Pago só traz o id do pagamento: o pagamento é sempre lido
# na API com o token da conta (a fonte da verdade), e o external_reference dele
# é o id do checkout. A assinatura x-signature é conferida quando a conta
# guardou a chave secreta dos webhooks (painel do Mercado Pago).
# Assinaturas: preapproval pendente que o cliente conclui no init_point. O
# preapproval não aceita notification_url: os avisos de assinatura só chegam
# com a URL do webhook cadastrada no painel (Suas integrações, Webhooks, eventos
# de Planos e assinaturas).
class Commerce::Gateways::MercadoPago
  API = 'https://api.mercadopago.com'.freeze
  SESSION_TTL = 23.hours
  # O external_reference do preapproval. Com prefixo, porque o pagamento de cada
  # ciclo também chega como aviso "payment" com esse external_reference, e o
  # aviso de pagamento procura um checkout por esse número.
  SUBSCRIPTION_REFERENCE = 'subscription-'.freeze
  SUBSCRIPTION_TOPICS = %w[subscription_preapproval subscription_authorized_payment].freeze

  def initialize(provider)
    @provider = provider
  end

  # Valida o token e a conta: só Mercado Pago Brasil (site MLB, BRL).
  def connect!
    site = request(:get, '/users/me')['site_id']
    fail_with("This Mercado Pago account is #{site}; only Mercado Pago Brasil (BRL) is supported") unless site == 'MLB'
  rescue Commerce::Gateways::Error => e
    fail_with(e.message)
  end

  def start!(checkout, return_url:, **)
    preference = request(:post, '/checkout/preferences', body: preference_params(checkout, return_url))
    url = sandbox_token? ? preference['sandbox_init_point'] : preference['init_point']
    checkout.update!(external_id: preference['id'], checkout_url: url)
  end

  # Pago se algum pagamento do checkout foi aprovado; recusado não encerra (o
  # cliente pode tentar de novo na mesma preferência).
  def status(checkout)
    payments = request(:get, '/v1/payments/search', query: { external_reference: checkout.id, sort: 'date_created', criteria: 'desc' })
    approved = Array(payments['results']).find { |payment| payment['status'] == 'approved' }
    approved ? result(approved) : { status: :pending }
  end

  def start_subscription!(subscription, return_url:, payer_email:)
    request(:post, '/preapproval', body: {
              reason: subscription.name, external_reference: "#{SUBSCRIPTION_REFERENCE}#{subscription.id}", payer_email: payer_email,
              back_url: return_url, status: 'pending',
              auto_recurring: { frequency: subscription.month? ? 1 : 12, frequency_type: 'months', currency_id: subscription.currency,
                                transaction_amount: subscription.amount.to_f }
            })['init_point']
  end

  # O Mercado Pago não cancela no fim do período: para de cobrar já, e a
  # assinatura fica ativa aqui até o fim do que foi pago (SubscriptionExpiryJob).
  def cancel_subscription!(subscription, **)
    request(:put, "/preapproval/#{subscription.external_id}", body: { status: 'cancelled' })
  end

  # [{ id: checkout }, resultado] para avisos de pagamento; os de assinatura são
  # aplicados aqui (Commerce::SubscriptionBilling) e devolvem nil, como os
  # outros (merchant_order, testes do painel).
  def webhook(http_request)
    params = http_request.query_parameters.merge(http_request.request_parameters)
    topic = params['type'] || params['topic']
    payment_id = params.dig('data', 'id') || params['data.id'] || params['id']
    return subscription_event(http_request, topic, payment_id) if SUBSCRIPTION_TOPICS.include?(topic)
    return unless topic == 'payment'

    verify!(http_request, payment_id)
    payment = request(:get, "/v1/payments/#{payment_id}")
    [{ id: payment['external_reference'] }, result(payment)]
  end

  private

  def preference_params(checkout, return_url)
    document = checkout.document
    labels = Commerce::DocumentLabels.for(document.language)
    {
      items: [{ id: document.number, title: "#{labels[:invoice]} #{document.number}", quantity: 1, currency_id: checkout.currency,
                unit_price: checkout.amount.to_f }],
      external_reference: checkout.id.to_s,
      notification_url: @provider.webhook_url,
      back_urls: { success: "#{return_url}?checkout=#{checkout.id}", pending: "#{return_url}?checkout=#{checkout.id}", failure: return_url },
      auto_return: 'approved',
      payer: document.customer['email'].to_s.match?(URI::MailTo::EMAIL_REGEXP) ? { email: document.customer['email'] } : nil,
      expires: true,
      expiration_date_to: SESSION_TTL.from_now.iso8601(3)
    }.compact
  end

  def subscription_event(http_request, topic, id)
    verify!(http_request, id)
    if topic == 'subscription_preapproval'
      preapproval_changed(request(:get, "/preapproval/#{id}"))
    else
      charge = request(:get, "/authorized_payments/#{id}")
      subscription = @provider.subscriptions.find_by(external_id: charge['preapproval_id']) ||
                     find_subscription(request(:get, "/preapproval/#{charge['preapproval_id']}"))
      charged(subscription, charge) if subscription
    end
    nil
  end

  # Autorizado: o cliente concluiu (liga o preapproval). Cancelado: no painel do
  # Mercado Pago ou aqui; com cancelamento no fim do período, quem encerra é o
  # SubscriptionExpiryJob.
  def preapproval_changed(preapproval)
    subscription = find_subscription(preapproval)
    return unless subscription

    billing = Commerce::SubscriptionBilling.new(subscription)
    billing.link!(preapproval['id']) if preapproval['status'] == 'authorized'
    billing.ended! if preapproval['status'] == 'cancelled' && !subscription.cancel_at_period_end
  end

  def find_subscription(preapproval)
    reference = preapproval['external_reference'].to_s
    @provider.subscriptions.find_by(id: reference.delete_prefix(SUBSCRIPTION_REFERENCE)) if reference.start_with?(SUBSCRIPTION_REFERENCE)
  end

  # Cada cobrança do ciclo: aprovada vira fatura paga e recibo; recusada deixa a
  # assinatura em atraso (o Mercado Pago tenta de novo). O período começa no dia
  # do débito.
  def charged(subscription, charge)
    billing = Commerce::SubscriptionBilling.new(subscription)
    case charge.dig('payment', 'status')
    when 'approved'
      start = Time.zone.parse((charge['debit_date'] || charge['date_created']).to_s).to_date
      billing.cycle_paid!(external_id: charge['id'].to_s, amount: BigDecimal(charge['transaction_amount'].to_s), period_start: start,
                          period_end: start + 1.public_send(subscription.interval))
    when 'rejected' then billing.payment_failed!
    end
  end

  def result(payment)
    status = payment['status'] == 'approved' ? :paid : :pending
    { status: status, amount: BigDecimal(payment['transaction_amount'].to_s), reference: payment['id'].to_s }
  end

  # Manifesto do Mercado Pago: "id:<data.id>;request-id:<x-request-id>;ts:<ts>;",
  # HMAC-SHA256 com a chave secreta dos webhooks.
  def verify!(http_request, payment_id)
    signature = http_request.headers['x-signature'].to_s
    return if @provider.webhook_secret.blank? || signature.blank?

    parts = signature.split(',').to_h { |part| part.strip.split('=', 2) }
    manifest = "id:#{payment_id.to_s.downcase};request-id:#{http_request.headers['x-request-id']};ts:#{parts['ts']};"
    expected = OpenSSL::HMAC.hexdigest('SHA256', @provider.webhook_secret, manifest)
    raise Commerce::Gateways::InvalidSignature unless ActiveSupport::SecurityUtils.secure_compare(expected, parts['v1'].to_s)
  end

  def sandbox_token?
    @provider.credential(:access_token).to_s.start_with?('TEST-')
  end

  def request(verb, path, query: nil, body: nil)
    response = HTTParty.public_send(verb, "#{API}#{path}", query: query, body: body&.to_json, timeout: 15,
                                                           headers: { 'Authorization' => "Bearer #{@provider.credential(:access_token)}",
                                                                      'Content-Type' => 'application/json' })
    return response.parsed_response if response.success?

    Rails.logger.warn("[COMMERCE] Mercado Pago (provider #{@provider.id}): HTTP #{response.code} #{response.body.to_s.truncate(200)}")
    raise Commerce::Gateways::Error, "Mercado Pago: HTTP #{response.code} #{response.parsed_response.try(:[], 'message')}".strip
  end

  def fail_with(message)
    @provider.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, @provider
  end
end
