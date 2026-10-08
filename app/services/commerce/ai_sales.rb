# O que o bot do n8n usa para vender com o catálogo (Commerce::BotController):
# os itens disponíveis com preço, o rascunho de cotização que a IA monta com os
# itens e as quantidades da conversa (a equipe revisa e envia; a nota interna
# menciona quem atende) e a assinatura de um plano, cujo link a IA manda.
class Commerce::AiSales
  MAX_ITEMS = 80

  def initialize(account)
    @account = account
  end

  def items
    @account.commerce_items.where(available: true).includes(:category).order(:position, :name).limit(MAX_ITEMS)
  end

  # O plano tem por onde ser assinado: uma forma de pagamento ativa cujo
  # provedor cobra assinatura na moeda dele.
  def subscription_method(item)
    return if item.billed_one_time? || item.price.nil?

    @account.commerce_payment_methods.online.includes(:provider).order(:position, :id).find do |method|
      Commerce::Subscription::PROVIDERS.include?(method.provider.provider) && method.provider.supports?(item.currency)
    end
  end

  # lines: [{ item_id:, quantity: }]. Itens de fora do catálogo disponível dão
  # 404. language: o idioma do cliente que o Jev viu (es, pt, en); sem ele, o da
  # conta. O rascunho da IA ainda não revisado da mesma conversa é atualizado
  # (o cliente mudou a quantidade), em vez de nascer outro.
  def quote!(conversation, lines, language: nil)
    contact = conversation.contact
    quote = Commerce::Document.awaiting_review.find_by(account: @account, conversation: conversation)
    updated = quote.present?
    quote ||= @account.commerce_documents.new(kind: :quote, issue_date: Date.current, details: { 'prepared_by_ai' => true }, **quote_defaults)
    Commerce::DocumentEditor.new(quote, {
                                   language: language_or_default(language), contact_id: contact.id, conversation_id: conversation.id,
                                   deal_id: @account.sales_deals.open.find_by(contact: contact)&.id,
                                   customer: Commerce.customer_of(contact), items: lines.map { |line| quote_line(line) }
                                 }).save!
    Commerce::TeamNote.post(quote, updated ? 'commerce.ai_quote_updated' : 'commerce.ai_quote')
    quote
  end

  # Uma assinatura aguardando do mesmo plano para o contato é reaproveitada: o
  # cliente que pede o link de novo recebe o mesmo.
  def subscribe!(conversation, item_id, language: nil)
    item = items.find(item_id)
    method = subscription_method(item) || raise(ActiveRecord::RecordNotFound, 'no payment method charges this plan')
    subscription = @account.commerce_subscriptions.pending.find_by(contact: conversation.contact, item: item) ||
                   @account.commerce_subscriptions.create!(contact: conversation.contact, item: item, payment_method: method,
                                                           language: language_or_default(language))
    subscription.update!(conversation: conversation, sent_at: Time.current)
    subscription
  end

  private

  def quote_line(line)
    item = items.find(line[:item_id])
    { item_id: item.id, name: item.name, description: item.description, unit: item.unit, unit_price: item.price,
      quantity: line[:quantity].presence || 1 }
  end

  def quote_defaults
    profile = Commerce::Profile.for(@account)
    { currency: profile.default_currency, terms: profile.default_terms, footer: profile.footer,
      payment_method_ids: @account.commerce_payment_methods.where(active: true).order(:position, :id).ids }
  end

  def language_or_default(language)
    language.presence_in(Commerce::Document::LANGUAGES) || @account.locale.to_s.first(2).presence_in(Commerce::Document::LANGUAGES) || 'es'
  end
end
