# Provisiona uma sessão de WhatsApp ponta a ponta:
#   1. Sessão no gateway OpenWA.
#   2. Inbox de API no Chatwoot com o webhook do canal apontando para o ingress
#      do chatwoot-adapter (entrega escopada à inbox, assinada com channel.secret).
#   3. Instância do chatwoot-adapter cunhada via REST com secret = channel.secret
#      (o painel do OpenWA gera um secret próprio que nunca bate — sempre REST).
#   4. Opcional: vínculo do agent bot à inbox + rota de persona no Supabase.
#   5. Start da sessão (o QR fica disponível para pareamento).
class Integrations::Openwa::ProvisionService
  pattr_initialize [:account!, :user!, :name!, :agent_bot_id, :inbox_id]

  def perform
    session = client.create_session(name)
    @session_id = session['id']
    @inbox = find_or_create_inbox
    client.create_adapter_instance(
      instance_id: name,
      session_id: @session_id,
      secret: @inbox.channel.secret,
      config: adapter_config
    )
    bind_agent_bot
    bot_route = create_bot_route
    client.start_session(@session_id)
    { session: client.session(@session_id), inbox_id: @inbox.id, bot_route: bot_route }
  rescue StandardError
    rollback
    raise
  end

  private

  # Reusa uma inbox de API existente (reapontando o webhook do canal para o
  # ingress desta sessão) ou cria uma nova dedicada.
  def find_or_create_inbox
    if inbox_id.present?
      inbox = account.inboxes.find(inbox_id)
      inbox.channel.update!(webhook_url: client.ingress_url(name))
      inbox
    else
      @created_inbox = true
      channel = Channel::Api.create!(account: account, webhook_url: client.ingress_url(name))
      account.inboxes.create!(name: "WhatsApp — #{name}", channel: channel)
    end
  end

  def adapter_config
    {
      baseUrl: ENV.fetch('FRONTEND_URL'),
      apiToken: user.access_token.token,
      accountId: account.id,
      inboxId: @inbox.id,
      relayMedia: true,
      relayOwnMessages: true
    }
  end

  def bind_agent_bot
    return if agent_bot_id.blank?

    binding = AgentBotInbox.find_or_initialize_by(inbox: @inbox)
    binding.agent_bot = agent_bot
    binding.status = :active
    binding.save!
  end

  def agent_bot
    @agent_bot ||= AgentBot.accessible_to(account).find(agent_bot_id)
  end

  # Insere a rota inbox → persona na camada de bots (Supabase/PostgREST) para o
  # workflow do n8n resolver a persona. Sem as envs, o passo fica pendente e o
  # status devolvido deixa isso visível na UI.
  def create_bot_route
    return 'skipped' if agent_bot_id.blank?
    return 'pending_env' if supabase_rest_url.blank? || supabase_service_key.blank?

    persona_id = fetch_persona_id
    return 'persona_not_found' if persona_id.blank?

    response = HTTParty.post(
      "#{supabase_rest_url}/bot_channel_routes?on_conflict=chatwoot_account_id,chatwoot_inbox_id",
      headers: supabase_headers.merge('Prefer' => 'return=minimal,resolution=merge-duplicates'),
      body: {
        chatwoot_account_id: account.id,
        chatwoot_inbox_id: @inbox.id,
        channel_label: @inbox.name,
        persona_id: persona_id,
        chatwoot_agent_bot_id: agent_bot_id.to_i,
        # O Guard verifica a assinatura do webhook contra o secret, e
        # Responde/Handoff autenticam como o bot com o access_token — os dois
        # por conta+inbox, não uma env/credential fixa — ver
        # RoutesController#resolved_agent_bot.
        chatwoot_agent_bot_secret: agent_bot.secret,
        chatwoot_agent_bot_access_token: agent_bot.access_token&.token,
        is_active: true
      }.to_json
    )
    response.success? ? 'created' : 'failed'
  end

  # Dentro da conta: o slug é único por conta desde `bot_layer_per_account.sql`,
  # e o slug padrão vem de uma config global — sem o recorte, provisionar um
  # WhatsApp apontaria para a persona homônima de quem tiver criado primeiro.
  def fetch_persona_id
    slug = GlobalConfigService.load('OPENWA_BOT_PERSONA_SLUG', 'nathan-whatsapp')
    response = HTTParty.get(
      "#{supabase_rest_url}/bot_personas?slug=eq.#{slug}&chatwoot_account_id=eq.#{@inbox.account_id}&select=id",
      headers: supabase_headers
    )
    response.success? ? response.parsed_response.dig(0, 'id') : nil
  end

  def supabase_rest_url
    GlobalConfigService.load('SUPABASE_REST_URL', nil)&.chomp('/')
  end

  def supabase_service_key
    GlobalConfigService.load('SUPABASE_SERVICE_ROLE_KEY', nil)
  end

  def supabase_headers
    {
      'apikey' => supabase_service_key,
      'Authorization' => "Bearer #{supabase_service_key}",
      'Content-Type' => 'application/json'
    }
  end

  # Desfaz o que já foi criado quando um passo falha, para não deixar sessão ou
  # inbox órfã; erros do próprio rollback não mascaram o erro original. Uma
  # inbox pré-existente reaproveitada nunca é destruída.
  def rollback
    client.delete_adapter_instance(name) if @inbox.present?
    @inbox.destroy! if @created_inbox && @inbox.present?
    client.delete_session(@session_id) if @session_id.present?
  rescue StandardError => e
    Rails.logger.warn("[openwa] rollback of session #{name} incomplete: #{e.message}")
  end

  def client
    @client ||= Integrations::Openwa::Client.new
  end
end
