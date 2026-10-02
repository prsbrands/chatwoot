# Saúde do bot em cada inbox, para a tela Conexões (e o ponto de alerta dela no
# sidebar).
#
# O bot só responde quando as duas pontas estão ligadas: o AgentBotInbox (é ele
# que faz o Chatwoot chamar o n8n) e a rota no Supabase com a persona e as
# credenciais do mesmo bot (é com elas que o Guard confere a assinatura). Ligar
# o bot pela tela nativa da inbox cria só a primeira ponta, e o Guard recusa
# toda mensagem sem que ninguém veja: em 02/10 achamos o Instagram e o
# Messenger da conta 1 mudos desde agosto, e a inbox do WhatsApp oficial nasceu
# assim.
class Api::V1::Accounts::Integrations::Botlayer::HealthController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  def show
    voice_inbox_ids = TwilioVoiceRoute.where(account_id: Current.account.id).pluck(:voice_inbox_id)

    render json: {
      inboxes: Current.account.inboxes.includes(agent_bot_inbox: :agent_bot).map do |inbox|
        inbox_health(inbox, routes_by_inbox[inbox.id], voice_inbox_ids.include?(inbox.id))
      end
    }
  end

  private

  def routes_by_inbox
    @routes_by_inbox ||= client.routes(Current.account.id).index_by { |route| route['chatwoot_inbox_id'] }
  end

  def personas
    @personas ||= client.personas(Current.account.id).to_h { |persona| [persona['id'], persona['display_name']] }
  end

  def inbox_health(inbox, route, voice)
    binding = inbox.agent_bot_inbox if inbox.agent_bot_inbox&.active?
    {
      inbox_id: inbox.id,
      agent_bot: binding && { id: binding.agent_bot.id, name: binding.agent_bot.name },
      route: route && {
        persona_id: route['persona_id'],
        persona_name: personas[route['persona_id']],
        is_active: route['is_active']
      },
      status: voice ? 'voice' : status(binding, route)
    }
  end

  def status(binding, route)
    active_route = route if route&.dig('is_active')
    return active_route ? 'route_without_bot' : 'none' if binding.nil?
    return 'bot_without_route' if active_route.nil?
    return 'stale_credentials' unless credentials_match?(binding, active_route)

    'ok'
  end

  # O Guard verifica a assinatura com o secret gravado na rota. Rota de outro
  # bot, ou sem secret/token (criada antes de 13/08), deixa o canal mudo.
  def credentials_match?(binding, route)
    route['chatwoot_agent_bot_id'] == binding.agent_bot_id &&
      route['chatwoot_agent_bot_secret'].present? &&
      route['chatwoot_agent_bot_access_token'].present?
  end
end
