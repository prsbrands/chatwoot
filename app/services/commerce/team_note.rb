# Nota interna na conversa do documento mencionando quem atende o negócio (ou o
# primeiro admin da conta): a menção vira notificação no sino. Usada quando o
# cliente ou a IA mexem num documento sem ninguém da equipe olhando.
module Commerce::TeamNote
  def self.post(document, key, link: document, **vars)
    conversation = document.conversation
    return unless conversation

    account = document.account
    user = document.deal&.assignee || account.administrators.order(:id).first
    tag = "[@#{user.available_name}](mention://user/#{user.id}/#{ERB::Util.url_encode(user.available_name)})"
    url = "#{ENV.fetch('FRONTEND_URL')}/app/accounts/#{account.id}/documents/#{link.id}"
    total = Commerce::DocumentLabels.money(document.total, document.currency, 'en')
    conversation.messages.create!(account: account, inbox: conversation.inbox, message_type: :outgoing, private: true,
                                  content: I18n.t(key, mention: tag, number: document.number, total: total, url: url, **vars))
  end
end
