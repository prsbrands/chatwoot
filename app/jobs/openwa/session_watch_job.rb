# A sessão de WhatsApp por QR cai sem avisar ninguém: o Chatwoot continuava
# achando a inbox viva, o bot e o follow-up "respondiam" num canal que não
# entrega, e a primeira notícia era o cliente reclamando. A cada 5 minutos
# (TriggerScheduledItemsJob) este job confere as sessões do gateway e marca a
# inbox com o Reauthorizable dos outros canais: alerta na barra lateral e na
# tela da inbox, e-mail aos admins, e a varredura de follow-up pula a inbox.
#
# Duas checagens seguidas fora de `ready` (AUTHORIZATION_ERROR_THRESHOLD = 2)
# antes de marcar: o gateway reiniciando passa por `starting` e não deve virar
# alerta. A sessão de volta a `ready` desmarca sozinha.
class Openwa::SessionWatchJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    client = Integrations::Openwa::Client.new
    status_by_session = client.sessions.to_h { |session| [session['id'], session['status']] }

    client.adapter_instances.each do |instance|
      config = instance['config'] || {}
      inbox = Inbox.find_by(id: config['inboxId'], account_id: config['accountId'])
      next unless inbox&.api?

      if status_by_session[instance['sessionScope']] == 'ready'
        inbox.channel.reauthorized!
      elsif !inbox.channel.reauthorization_required?
        inbox.channel.authorization_error!
      end
    end
  end
end
