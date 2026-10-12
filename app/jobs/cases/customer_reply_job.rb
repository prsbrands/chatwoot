# A resposta do cliente a uma pergunta que a equipe mandou pela IA vai para o
# caso (Cases::AiCases#customer_replied!). Chamado por toda mensagem do cliente
# nas contas com a flag `cases`; sem caso esperando, não faz nada.
class Cases::CustomerReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.conversation&.contact

    Cases::AiCases.new(message.account).customer_replied!(message)
  end
end
