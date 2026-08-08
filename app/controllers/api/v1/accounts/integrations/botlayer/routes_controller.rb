class Api::V1::Accounts::Integrations::Botlayer::RoutesController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  def index
    render json: { routes: client.routes(Current.account.id) }
  end

  # Upsert por (conta, inbox): cria a rota se não existe, atualiza se existe.
  def create
    inbox = Current.account.inboxes.find(route_params[:chatwoot_inbox_id])
    render json: client.upsert_route(
      route_params.to_h.merge(
        chatwoot_account_id: Current.account.id,
        channel_label: inbox.name
      )
    )
  end

  def destroy
    client.delete_route(params[:id])
    head :ok
  end

  private

  def route_params
    params.permit(:chatwoot_inbox_id, :persona_id, :is_active, :channel_kind)
  end
end
