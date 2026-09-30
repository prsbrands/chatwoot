class Captain::JevClient
  include Integrations::LlmInstrumentationConstants

  ENDPOINT = 'https://openrouter.ai/api'.freeze
  SYSTEM_ONE_PATH = '/v1/systemone'.freeze
  # CortexGen: cada conta usa a propria chave da TypeSafe (cartao do Jev em AI
  # Providers), direto na TypeSafe. A chave global do OpenRouter (self.api_key)
  # so serve aos monitores do enterprise, que nao rodam nesta edicao.
  TYPESAFE_URL = 'https://api.typesafe.ai/v1/systemone'.freeze
  # O consentimento da tela promete o state sem e-mail, telefone e CPF — os
  # mesmos cortes do n8n (ops/n8n/jev_entrada.js).
  REDACTIONS = {
    /[\w.+-]+@[\w-]+(\.[\w-]+)+/ => '[email]',
    /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/ => '[cpf]',
    /\+?\d[\d\s().-]{7,}\d/ => '[phone]'
  }.freeze

  # A flag captain_classifier so liga pelo cartao com a chave conferida e o
  # consentimento dado; chegar aqui sem eles e configuracao quebrada.
  class NotConfigured < StandardError; end

  class HTTPError < StandardError
    attr_reader :status, :retry_after

    def initialize(response)
      @status = response.status
      @retry_after = response.headers['retry-after']&.to_i
      super("Jev request failed with status #{status}: #{response.body}")
    end
  end

  def initialize(account_id:, feature:, conversation_id: nil)
    @account_id = account_id
    @conversation_id = conversation_id
    @feature = feature
  end

  def self.request_body(model:, state:, questions:)
    { model: model, state: state, questions: questions }.to_json
  end

  def self.api_key
    GlobalConfigService.load('CAPTAIN_OPENROUTER_API_KEY', nil)
  end

  def self.endpoint
    base_url = GlobalConfigService.load('CAPTAIN_OPENROUTER_DECISION_MODEL_ENDPOINT', nil).presence || ENDPOINT
    "#{base_url.chomp('/')}#{SYSTEM_ONE_PATH}"
  end

  def call(body:)
    body = redacted(body)
    trace_jev_call(body) do
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = connection.post(TYPESAFE_URL, body)
      unless response.success?
        record_call(started_at, status: 'error', error: "HTTP #{response.status}")
        raise HTTPError, response
      end

      data = JSON.parse(response.body)
      record_call(started_at, status: 'ok', model: data['model'], input_tokens: data.dig('usage', 'input_tokens'))
      yield(data) if block_given?
      data
    end
  end

  private

  def trace_jev_call(body, &)
    return yield unless ChatwootApp.otel_enabled?

    traced_jev_call(body, &)
  end

  # Tracing is best-effort: a tracing failure must not block the Jev call or discard a response that already used provider credit.
  def traced_jev_call(body, &)
    outcome = {}
    OpentelemetryConfig.tracer.in_span("llm.jev.#{@feature}", kind: :client) do |span|
      request_model = JSON.parse(body).fetch('model')
      set_request_attributes(span, body)
      call_in_span(span, outcome, &)
      set_response_attributes(span, outcome[:result], request_model)
    end
    outcome[:result]
  rescue StandardError => e
    raise outcome[:error] if outcome.key?(:error)

    ChatwootExceptionTracker.new(e).capture_exception
    outcome.key?(:result) ? outcome[:result] : yield
  end

  def call_in_span(span, outcome)
    outcome[:result] = yield
  rescue StandardError => e
    outcome[:error] = e
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    raise
  end

  def set_request_attributes(span, body)
    span.set_attribute(ATTR_LANGFUSE_OBSERVATION_TYPE, 'generation')
    span.set_attribute(ATTR_LANGFUSE_OBSERVATION_INPUT, body)
    span.set_attribute(ATTR_LANGFUSE_USER_ID, @account_id.to_s)
    span.set_attribute(ATTR_LANGFUSE_TAGS, [@feature].to_json)
    span.set_attribute(ATTR_LANGFUSE_SESSION_ID, "#{@account_id}_#{@conversation_id}") if @conversation_id
  end

  def set_response_attributes(span, result, request_model)
    usage = result['usage'] || {}
    span.set_attribute(ATTR_LANGFUSE_OBSERVATION_OUTPUT, result.to_json)
    span.set_attribute(ATTR_LANGFUSE_OBSERVATION_MODEL_NAME, result['model'] || request_model)
    span.set_attribute(ATTR_GEN_AI_USAGE_INPUT_TOKENS, usage['input_tokens']) if usage['input_tokens']
    span.set_attribute(ATTR_GEN_AI_USAGE_OUTPUT_TOKENS, usage['output_tokens']) if usage['output_tokens']
    span.set_attribute(ATTR_LANGFUSE_OBSERVATION_COST_DETAILS, { total: usage['cost'] }.to_json) if usage['cost'].is_a?(Numeric)
  end

  def connection
    Faraday.new do |client|
      client.options.open_timeout = 3
      client.options.timeout = 15
      client.headers['Authorization'] = "Bearer #{account_api_key}"
      client.headers['Content-Type'] = 'application/json'
    end
  end

  def botlayer
    @botlayer ||= Integrations::Botlayer::Client.new
  end

  def account_api_key
    settings = botlayer.account_settings(@account_id)
    config = settings['jev'] || {}
    ready = settings['jev_api_key'].present? && config['enabled'] && config['consent']
    raise NotConfigured, "Jev is not on for account #{@account_id}" unless ready

    settings['jev_api_key']
  end

  def redacted(body)
    payload = JSON.parse(body)
    payload['state'] = redact(payload['state'])
    payload.to_json
  end

  def redact(value)
    case value
    when String then REDACTIONS.reduce(value) { |text, (pattern, mask)| text.gsub(pattern, mask) }
    when Array then value.map { |item| redact(item) }
    when Hash then value.transform_values { |item| redact(item) }
    else value
    end
  end

  # Custo e falhas no mesmo log do bot (bot_jev_calls), para o cartao do Jev
  # somar tudo o que a conta gasta com ele.
  def record_call(started_at, status:, model: nil, input_tokens: nil, error: nil)
    botlayer.record_jev_call(
      chatwoot_account_id: @account_id, chatwoot_conversation_id: @conversation_id, phase: 'team',
      model: model, input_tokens: input_tokens, status: status, error: error,
      latency_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round,
      decisions: { @feature => { state: 'on' } }
    )
  end
end
