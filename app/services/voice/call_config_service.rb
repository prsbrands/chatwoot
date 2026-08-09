# Tudo o que o serviço de mídia precisa para conduzir uma chamada, numa
# resposta só. As chaves de LLM, transcrição e voz ficam guardadas aqui e são
# entregues por chamada — o serviço de mídia não tem cofre próprio nem env com
# credencial de cliente.
class Voice::CallConfigService
  class MisconfiguredError < StandardError; end

  def initialize(route:)
    @route = route
  end

  def perform
    {
      call: { account_id: @route.account_id, phone_number: @route.phone_number },
      persona: persona_payload,
      llm: llm_payload,
      stt: stt_payload,
      tts: tts_payload
    }
  end

  private

  def persona
    @persona ||= begin
      slug = @route.bot_persona_slug.presence ||
             raise(MisconfiguredError, "#{@route.phone_number} is not routed to a bot")

      client.resolved_persona(slug) || raise(MisconfiguredError, "persona '#{slug}' not found in the bot layer")
    end
  end

  def providers
    @providers ||= client.providers(@route.account_id).index_by { |provider| provider['slug'] }
  end

  # Uma persona pode apontar para um fornecedor que a conta não tem — a persona é
  # global e a chave é por conta. Falhar aqui, com o nome do que falta, é melhor
  # do que descobrir isso com o cliente na linha.
  def provider!(slug, purpose)
    provider = providers[slug.to_s]
    raise MisconfiguredError, "no #{purpose} provider '#{slug}' with a key on this account" if provider.blank? || provider['api_key'].blank?

    provider
  end

  def persona_payload
    {
      slug: persona['persona_slug'],
      display_name: persona['display_name'],
      system_prompt: persona['composed_prompt'],
      first_message: persona['voice_first_message'],
      language: persona['voice_language'],
      greeting_delay_ms: persona['voice_greeting_delay_ms'],
      endpoint_ms: persona['voice_endpoint_ms'],
      interruptible: persona['voice_interruptible']
    }
  end

  def llm_payload
    provider = provider!(persona['provider'], 'language model')
    {
      base_url: provider['base_url'],
      api_key: provider['api_key'],
      api_style: provider['api_style'],
      model: persona['model'],
      temperature: persona['temperature'].to_f,
      max_tokens: persona['max_tokens']
    }
  end

  def stt_payload
    provider = provider!(persona['stt_provider'], 'transcription')
    {
      base_url: provider['base_url'],
      api_key: provider['api_key'],
      api_style: provider['api_style'],
      model: persona['stt_model']
    }
  end

  def tts_payload
    provider = provider!(persona['tts_provider'], 'voice')
    {
      base_url: provider['base_url'],
      api_key: provider['api_key'],
      api_style: provider['api_style'],
      model: persona['tts_model'],
      voice_id: persona['tts_voice_id']
    }
  end

  def client
    @client ||= Integrations::Botlayer::Client.new
  end
end
