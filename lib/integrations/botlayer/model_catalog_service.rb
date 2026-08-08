# Lê o catálogo de modelos direto do endpoint /models do fornecedor, para a
# lista no painel nunca depender de uma tabela fixa que envelhece.
class Integrations::Botlayer::ModelCatalogService
  class FetchError < StandardError; end

  ANTHROPIC_VERSION = '2023-06-01'.freeze

  pattr_initialize [:provider!]

  def perform
    response = HTTParty.get("#{provider['base_url'].chomp('/')}/models", headers: headers, timeout: 20)
    raise FetchError, error_message(response) unless response.success?

    ids = Array(response.parsed_response['data']).filter_map { |model| model['id'] }.sort
    raise FetchError, I18n.t('errors.botlayer.no_models') if ids.empty?

    ids.map { |id| { 'id' => id } }
  end

  private

  def headers
    return { 'x-api-key' => api_key.to_s, 'anthropic-version' => ANTHROPIC_VERSION } if provider['api_style'] == 'anthropic'

    api_key.present? ? { 'Authorization' => "Bearer #{api_key}" } : {}
  end

  def api_key
    provider['api_key']
  end

  def error_message(response)
    body = response.parsed_response
    message = body.dig('error', 'message') if body.is_a?(Hash)
    message.presence || "HTTP #{response.code}"
  end
end
