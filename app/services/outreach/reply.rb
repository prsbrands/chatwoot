# A resposta do cliente volta para a campanha que falou com ele. O adaptador do
# OpenWA cria o contato e a conversa quando a pessoa responde, então é aqui que
# a linha da lista ganha contato e conversa. Vale a campanha mais recente do
# mesmo número cuja janela de atribuição ainda está aberta; fora dela é uma
# conversa que começou por outro motivo. Quem responde um pedido de parada vira
# `opted_out` (o `OptOut` do bot já bloqueou o contato).
class Outreach::Reply
  def initialize(message)
    @message = message
    @contact = message.conversation.contact
  end

  def perform
    phone = contact_phone
    return if phone.blank?

    recipient = candidates(phone).find { |item| @message.created_at <= item.sent_at + item.campaign.attribution_hours.hours }
    return unless recipient

    recipient.update!(status: @contact.blocked? ? :opted_out : :replied, replied_at: @message.created_at,
                      contact_id: @contact.id, conversation_id: @message.conversation_id)
  end

  private

  # O adaptador chaveia o contato pelo JID e pode não ter o telefone.
  def contact_phone
    return @contact.phone_number if @contact.phone_number.present?

    identifier = @contact.identifier.to_s
    "+#{identifier.split('@').first}" if identifier.end_with?('@c.us')
  end

  def candidates(phone)
    Outreach::Recipient.where(account_id: @message.account_id, phone: phone, status: :sent).where.not(sent_at: nil)
                       .joins(:campaign).merge(Outreach::Campaign.where(inbox_id: @message.inbox_id))
                       .preload(:campaign).order(sent_at: :desc)
  end
end
