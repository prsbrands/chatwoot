class Integrations::Openwa::Client
  class ApiError < StandardError; end

  ADAPTER_PLUGIN_ID = 'chatwoot-adapter'.freeze

  def self.configured?
    ENV['OPENWA_API_URL'].present? && ENV['OPENWA_API_KEY'].present?
  end

  def sessions
    get('sessions')
  end

  def session(session_id)
    get("sessions/#{session_id}")
  end

  def create_session(name)
    post('sessions', { name: name })
  end

  def start_session(session_id)
    post("sessions/#{session_id}/start")
  end

  def stop_session(session_id)
    post("sessions/#{session_id}/stop")
  end

  def logout_session(session_id)
    post("sessions/#{session_id}/logout")
  end

  def delete_session(session_id)
    delete("sessions/#{session_id}")
  end

  def qr(session_id)
    get("sessions/#{session_id}/qr")
  end

  def adapter_instances
    get("integration/plugins/#{ADAPTER_PLUGIN_ID}/instances")
  end

  def create_adapter_instance(instance_id:, session_id:, secret:, config:)
    post("integration/plugins/#{ADAPTER_PLUGIN_ID}/instances",
         { instanceId: instance_id, sessionScope: session_id, secret: secret, config: config })
  end

  def delete_adapter_instance(instance_id)
    delete("integration/plugins/#{ADAPTER_PLUGIN_ID}/instances/#{instance_id}")
  end

  # A URL de ingress é determinística, o que permite apontar o webhook do canal
  # para ela antes mesmo de cunhar a instância do adapter.
  def ingress_url(instance_id)
    "#{base_url}/api/ingress/#{ADAPTER_PLUGIN_ID}/#{instance_id}/chatwoot"
  end

  private

  def base_url
    ENV.fetch('OPENWA_API_URL').chomp('/')
  end

  def headers
    { 'X-API-Key' => ENV.fetch('OPENWA_API_KEY'), 'Content-Type' => 'application/json' }
  end

  def get(path)
    process(HTTParty.get("#{base_url}/api/#{path}", headers: headers))
  end

  def post(path, payload = nil)
    process(HTTParty.post("#{base_url}/api/#{path}", { headers: headers, body: payload&.to_json }.compact))
  end

  def delete(path)
    process(HTTParty.delete("#{base_url}/api/#{path}", headers: headers))
  end

  def process(response)
    raise ApiError, error_message(response) unless response.success?

    response.parsed_response
  end

  def error_message(response)
    body = response.parsed_response
    message = body.is_a?(Hash) ? (body['message'] || body['error']) : nil
    Array(message).join(', ').presence || "OpenWA API error (HTTP #{response.code})"
  end
end
