# Atribui a resposta do cliente à campanha por QR (Outreach::Reply). Roda um
# minuto depois da mensagem, para o `OptOut` do bot já ter bloqueado o contato
# quando a resposta foi um pedido de parar.
class Outreach::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.conversation&.contact

    Outreach::Reply.new(message).perform
  end
end
