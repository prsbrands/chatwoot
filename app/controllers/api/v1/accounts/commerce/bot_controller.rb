# O que o bot do n8n usa para vender com o catálogo (com o token de usuário da
# conta, o mesmo da Agenda): os itens disponíveis, o rascunho de cotização que
# a IA monta e a assinatura de um plano (Commerce::AiSales).
class Api::V1::Accounts::Commerce::BotController < Api::V1::Accounts::Commerce::BaseController
  before_action -> { authorize ::Commerce::Document, :create? }

  def catalog
    sales = ::Commerce::AiSales.new(Current.account)
    render json: {
      items: sales.items.map do |item|
        { id: item.id, name: item.name, kind: item.kind, category: item.category&.name, description: item.description.to_s.truncate(300),
          price: item.price&.to_s, currency: item.currency, unit: item.unit, billing_interval: item.billing_interval,
          subscribable: sales.subscription_method(item).present? }
      end
    }
  end

  # lines: [{ item_id, quantity }]
  def quote
    lines = params.require(:lines).map { |line| line.permit(:item_id, :quantity).to_h.symbolize_keys }
    quote = ::Commerce::AiSales.new(Current.account).quote!(conversation, lines, language: params[:language])
    render json: { id: quote.id, number: quote.number }
  end

  def subscribe
    subscription = ::Commerce::AiSales.new(Current.account).subscribe!(conversation, params.require(:item_id), language: params[:language])
    render json: { id: subscription.id, public_url: subscription.public_url }
  end

  private

  def conversation
    Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
  end
end
