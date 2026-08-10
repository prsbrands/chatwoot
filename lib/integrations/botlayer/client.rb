# Client PostgREST para a camada de bots no Supabase (tabelas bot_*).
# A service key fica só no servidor; o frontend nunca fala com o Supabase.
class Integrations::Botlayer::Client
  class ApiError < StandardError; end

  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  SLUG_FORMAT = /\A[a-z0-9][a-z0-9-]*\z/

  # Configuração fica em Super Admin → Settings → Bot Layer. O
  # GlobalConfigService cai no ENV enquanto o InstallationConfig não existir, e
  # grava o valor do ENV na primeira leitura.
  def self.configured?
    GlobalConfigService.load('SUPABASE_REST_URL', nil).present? && GlobalConfigService.load('SUPABASE_SERVICE_ROLE_KEY', nil).present?
  end

  # Persona e base de conhecimento são da conta, como as chaves de LLM: é o
  # `system_prompt` do cliente, a lógica de negócio dele. O filtro por conta vai
  # em toda leitura e escrita — inclusive nas de id conhecido, senão saber o
  # UUID de uma persona alheia bastaria para editá-la.
  def personas(account_id)
    get("bot_personas?chatwoot_account_id=eq.#{account_id.to_i}&select=*,bot_persona_knowledge(doc_id)&order=created_at.asc")
  end

  def create_persona(account_id, attributes)
    post('bot_personas', attributes.merge(chatwoot_account_id: account_id.to_i)).first
  end

  def update_persona(account_id, id, attributes)
    patch("bot_personas?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}", attributes).first
  end

  def delete_persona(account_id, id)
    delete("bot_personas?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}")
  end

  # Persona com a base de conhecimento já concatenada. É o que a chamada de voz
  # consome: uma leitura, sem montar prompt do lado do Rails.
  #
  # O slug só é único dentro da conta desde `bot_layer_per_account.sql`, então
  # pedir por slug sem a conta passaria a devolver a persona de quem chegou
  # primeiro.
  def resolved_persona(account_id, slug)
    get("bot_persona_resolved?persona_slug=eq.#{slug!(slug)}&chatwoot_account_id=eq.#{account_id.to_i}&select=*").first
  end

  def knowledge_docs(account_id)
    get("bot_knowledge_docs?chatwoot_account_id=eq.#{account_id.to_i}&select=*,bot_persona_knowledge(persona_id)&order=priority.asc,created_at.asc")
  end

  def create_knowledge_doc(account_id, attributes)
    post('bot_knowledge_docs', attributes.merge(chatwoot_account_id: account_id.to_i)).first
  end

  def update_knowledge_doc(account_id, id, attributes)
    patch("bot_knowledge_docs?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}", attributes).first
  end

  def delete_knowledge_doc(account_id, id)
    delete("bot_knowledge_docs?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}")
  end

  # Substitui os vínculos persona↔doc de um documento (doc não-global entra no
  # prompt apenas das personas vinculadas).
  #
  # As personas são conferidas contra a conta antes de gravar: `bot_persona_knowledge`
  # é só um par de UUIDs e não tem conta própria, então é aqui que se impede
  # pendurar o documento de uma conta na persona de outra.
  def set_doc_personas(account_id, doc_id, persona_ids)
    delete("bot_persona_knowledge?doc_id=eq.#{uuid!(doc_id)}")
    return if persona_ids.blank?

    owned = personas(account_id).map { |persona| persona['id'] }
    links = persona_ids.map { |id| uuid!(id) }.select { |id| owned.include?(id) }
    return if links.blank?

    post('bot_persona_knowledge', links.map { |persona_id| { doc_id: doc_id, persona_id: persona_id } })
  end

  # Credenciais de LLM são por conta: cada cliente do painel só enxerga e edita
  # as próprias chaves. O filtro por conta é aplicado em toda leitura e escrita.
  def providers(account_id)
    get("bot_providers?chatwoot_account_id=eq.#{account_id.to_i}&select=*&order=label.asc")
  end

  def provider(account_id, id)
    get("bot_providers?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}&select=*").first
  end

  def create_provider(account_id, attributes)
    post('bot_providers', attributes.merge(chatwoot_account_id: account_id.to_i)).first
  end

  def update_provider(account_id, id, attributes)
    patch("bot_providers?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}", attributes).first
  end

  def delete_provider(account_id, id)
    delete("bot_providers?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}")
  end

  def routes(account_id)
    get("bot_channel_routes?chatwoot_account_id=eq.#{account_id.to_i}&order=chatwoot_inbox_id.asc")
  end

  def route(account_id, id)
    get("bot_channel_routes?id=eq.#{uuid!(id)}&chatwoot_account_id=eq.#{account_id.to_i}").first
  end

  def upsert_route(attributes)
    post(
      'bot_channel_routes?on_conflict=chatwoot_account_id,chatwoot_inbox_id',
      attributes,
      prefer: 'return=representation,resolution=merge-duplicates'
    ).first
  end

  def delete_route(id)
    delete("bot_channel_routes?id=eq.#{uuid!(id)}")
  end

  private

  def uuid!(value)
    raise ApiError, "invalid uuid: #{value}" unless value.to_s.match?(UUID_FORMAT)

    value
  end

  def slug!(value)
    raise ApiError, "invalid slug: #{value}" unless value.to_s.match?(SLUG_FORMAT)

    value
  end

  def base_url
    GlobalConfigService.load('SUPABASE_REST_URL', nil).chomp('/')
  end

  def headers(prefer = nil)
    key = GlobalConfigService.load('SUPABASE_SERVICE_ROLE_KEY', nil)
    base = { 'apikey' => key, 'Authorization' => "Bearer #{key}", 'Content-Type' => 'application/json' }
    base['Prefer'] = prefer if prefer
    base
  end

  def get(path)
    process(HTTParty.get("#{base_url}/#{path}", headers: headers))
  end

  def post(path, payload, prefer: 'return=representation')
    process(HTTParty.post("#{base_url}/#{path}", headers: headers(prefer), body: payload.to_json))
  end

  def patch(path, payload)
    process(HTTParty.patch("#{base_url}/#{path}", headers: headers('return=representation'), body: payload.to_json))
  end

  def delete(path)
    process(HTTParty.delete("#{base_url}/#{path}", headers: headers))
  end

  def process(response)
    raise ApiError, error_message(response) unless response.success?

    response.body.present? ? response.parsed_response : nil
  end

  def error_message(response)
    body = response.parsed_response
    message = body.is_a?(Hash) ? [body['message'], body['details'], body['hint']].compact.join(' — ') : nil
    message.presence || "Supabase error (HTTP #{response.code})"
  end
end
