# A rota da camada de bots (Bot Personas -> Channels, no Supabase) morre com a
# inbox. Sem isto ela ficava orfa e a varredura de follow-up tentava ler uma
# inbox que nao existe.
module InboxBotRoutes
  extend ActiveSupport::Concern

  included do
    after_destroy_commit :remove_bot_routes
  end

  private

  def remove_bot_routes
    return unless Integrations::Botlayer::Client.configured?

    Integrations::Botlayer::Client.new.delete_inbox_routes(account_id, id)
  end
end
