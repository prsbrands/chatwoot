# Abre o negocio do contato no funil padrao na primeira mensagem dele numa
# inbox com bot (as portas de entrada de venda). Contato com negocio aberto
# nao ganha outro; Sales::Deal.open_for_contact! trava o contato para tres
# mensagens seguidas nao virarem tres negocios.
class SalesDealListener < BaseListener
  def message_created(event)
    message, account = extract_message_and_account(event)
    return unless message.incoming? && !message.private?
    return unless account.feature_enabled?('sales_pipeline')
    return unless message.inbox.active_bot?

    contact = message.conversation.contact
    return if contact.blank? || contact.blocked?
    return if account.sales_deals.open.exists?(contact: contact)

    Sales::Deal.open_for_contact!(contact, conversation: message.conversation)
  end
end
