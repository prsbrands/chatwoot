# Yappy (Banco General, Panamá), Botón de Pago V2, em USD. Não há página do
# provedor: o cliente informa o celular Yappy na página da fatura, a ordem é
# criada com ele (aliasYappy) e o cliente aprova no app. O Yappy não tem
# consulta de situação: quem confirma é o aviso (IPN, GET) com o hash
# HMAC-SHA256 de orderId+status+domain, obrigatório, com a 1ª parte da chave
# secreta decodificada. O aviso não traz valor: vale o da ordem criada aqui.
class Commerce::Gateways::Yappy
  BASE_URLS = { 'sandbox' => 'https://api-comecom-uat.yappycloud.com', 'production' => 'https://apipagosbg.bgeneral.cloud' }.freeze
  OK_CODES = %w[00 0000].freeze
  # Situação no aviso: E executado, R recusado, C cancelado, X expirado.
  IPN_STATUS = { 'E' => :paid, 'R' => :failed, 'C' => :failed, 'X' => :expired }.freeze

  def initialize(provider)
    @provider = provider
  end

  # Valida o ID do comércio e o domínio cadastrados no Yappy Comercial e o
  # formato da chave secreta (base64 de "<chave>.<...>").
  def connect!
    fail_with('Invalid Yappy secret key') if hash_key.blank?
    validate_merchant
  rescue Commerce::Gateways::Error, ArgumentError => e
    fail_with(e.message)
  end

  def start!(checkout, phone: nil, **)
    alias_yappy = phone.to_s.gsub(/\D/, '')
    raise Commerce::Gateways::Error, 'Yappy needs the 8-digit Yappy phone number' unless alias_yappy.match?(/\A\d{8}\z/)

    merchant = validate_merchant
    order_id = "CG#{checkout.id}"
    order = post('/payments/payment-wc', order_params(checkout, order_id, merchant['epochTime'], alias_yappy),
                 'Authorization' => merchant['token'])
    checkout.update!(external_id: order_id, payload: order.slice('transactionId', 'documentName'))
  end

  # Sem consulta no Yappy: segue pendente até o aviso (ou expirar).
  def status(_checkout)
    { status: :pending }
  end

  # [{ external_id: orderId }, resultado] do aviso do Yappy.
  def webhook(http_request)
    params = http_request.query_parameters
    order_id = params['orderId'].to_s
    status = params['status'].to_s
    received = (params['hash'] || params['Hash']).to_s
    expected = OpenSSL::HMAC.hexdigest('SHA256', hash_key.to_s, "#{order_id}#{status}#{params['domain']}")
    raise Commerce::Gateways::InvalidSignature unless received.present? && ActiveSupport::SecurityUtils.secure_compare(expected, received.downcase)

    checkout = @provider.checkouts.find_by(external_id: order_id)
    [{ external_id: order_id }, { status: IPN_STATUS.fetch(status, :pending), amount: checkout&.amount, reference: params['confirmationNumber'] }]
  end

  private

  def validate_merchant
    post('/payments/validate/merchant', { merchantId: @provider.credential(:merchant_id), urlDomain: domain })
  end

  def order_params(checkout, order_id, epoch, alias_yappy)
    total = format('%.2f', checkout.amount)
    { merchantId: @provider.credential(:merchant_id), orderId: order_id, domain: domain, paymentDate: epoch || Time.current.to_i,
      ipnUrl: @provider.webhook_url, discount: '0.00', taxes: '0.00', subtotal: total, total: total, aliasYappy: alias_yappy }
  end

  # O domínio cadastrado no Yappy Comercial; sem ele, o desta instalação.
  def domain
    @provider.credential(:domain).presence || ENV.fetch('FRONTEND_URL')
  end

  def hash_key
    Base64.strict_decode64(@provider.credential(:secret_key).to_s).split('.').first
  rescue ArgumentError
    nil
  end

  def post(path, body, headers = {})
    response = HTTParty.post("#{BASE_URLS.fetch(@provider.environment)}#{path}", body: body.to_json, timeout: 15,
                                                                                 headers: { 'Content-Type' => 'application/json' }.merge(headers))
    data = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    return data['body'] || {} if response.success? && OK_CODES.include?(data.dig('status', 'code'))

    Rails.logger.warn("[COMMERCE] Yappy (provider #{@provider.id}) #{path}: HTTP #{response.code} #{response.body.to_s.truncate(200)}")
    raise Commerce::Gateways::Error, "Yappy: #{data.dig('status', 'description') || "HTTP #{response.code}"} (#{data.dig('status', 'code')})"
  end

  def fail_with(message)
    @provider.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, @provider
  end
end
