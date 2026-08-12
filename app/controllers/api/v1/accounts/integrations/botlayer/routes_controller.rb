class Api::V1::Accounts::Integrations::Botlayer::RoutesController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  def index
    render json: { routes: client.routes(Current.account.id) }
  end

  # Upsert por (conta, inbox): cria a rota se não existe, atualiza se existe.
  def create
    inbox = Current.account.inboxes.find(route_params[:chatwoot_inbox_id])
    return render_voice_inbox_error if activating_voice_inbox?(inbox)

    ensure_persona_belongs_to_account!
    route = client.upsert_route(
      route_params.to_h.merge(
        chatwoot_account_id: Current.account.id,
        channel_label: inbox.name
      )
    )
    sync_agent_bot(inbox, route['chatwoot_agent_bot_id'], route['is_active'])
    render json: route
  end

  def destroy
    route = client.route(Current.account.id, params[:id])
    client.delete_route(params[:id])
    inbox = Current.account.inboxes.find_by(id: route&.dig('chatwoot_inbox_id'))
    detach_bot(inbox, route['chatwoot_agent_bot_id']) if inbox.present?
    head :ok
  end

  private

  # A inbox "Voz — <número>" é só o registro passivo da chamada: quem conversa
  # com quem liga é o cortexgen-voice, direto pela persona da TwilioVoiceRoute,
  # sem passar pelo webhook padrão do Chatwoot. Um bot de texto amarrado nela
  # responde à própria transcrição como se fosse um chat ao vivo — visto em
  # produção em 12/08 na conta dagente. Desligar (is_active: false) continua
  # liberado, para dar como desfazer uma rota que já ficou ligada por engano.
  def activating_voice_inbox?(inbox)
    ActiveModel::Type::Boolean.new.cast(route_params[:is_active]) &&
      TwilioVoiceRoute.exists?(account_id: Current.account.id, voice_inbox_id: inbox.id)
  end

  def render_voice_inbox_error
    render json: { error: I18n.t('errors.botlayer.voice_inbox_not_allowed') }, status: :unprocessable_entity
  end

  # O `persona_id` vem do navegador, e a inbox ser da conta não diz nada sobre a
  # persona. Sem esta conferência, apontar a própria inbox para o UUID de uma
  # persona alheia faria o bot responder com o prompt de outro cliente.
  def ensure_persona_belongs_to_account!
    persona_id = route_params[:persona_id]
    return if persona_id.blank?
    return if client.personas(Current.account.id).any? { |persona| persona['id'] == persona_id }

    raise Pundit::NotAuthorizedError
  end

  # A rota no Supabase só dá persona ao bot; quem faz o Chatwoot disparar o
  # webhook é o AgentBotInbox. Ligar as duas pontas na mesma ação evita o canal
  # com rota ativa e bot mudo (ou o inverso, webhook sem persona).
  def sync_agent_bot(inbox, agent_bot_id, is_active)
    return if agent_bot_id.blank?

    agent_bot = AgentBot.accessible_to(Current.account).find(agent_bot_id)
    return detach_bot(inbox, agent_bot.id) unless is_active

    binding = inbox.agent_bot_inbox || AgentBotInbox.new(inbox: inbox)
    binding.agent_bot = agent_bot
    binding.status = :active
    binding.save!
  end

  # Só desfaz o vínculo que esta rota criou — um bot atribuído por fora
  # (Settings → Inboxes → Bot Configuration) não é da nossa alçada.
  def detach_bot(inbox, agent_bot_id)
    inbox.agent_bot_inbox.destroy! if inbox.agent_bot_inbox&.agent_bot_id == agent_bot_id.to_i
  end

  def route_params
    params.permit(:chatwoot_inbox_id, :persona_id, :is_active, :channel_kind, :chatwoot_agent_bot_id)
  end
end
