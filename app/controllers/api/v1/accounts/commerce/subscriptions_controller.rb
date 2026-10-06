# Assinaturas da conta. Criar copia o plano (item com billing_interval) e o
# cliente (Commerce::Subscription); o link /s/:token vai pela conversa e o
# cliente assina pelo provedor.
class Api::V1::Accounts::Commerce::SubscriptionsController < Api::V1::Accounts::Commerce::BaseController
  before_action :fetch_subscription, except: [:index, :create]
  before_action -> { check_authorization(@subscription || ::Commerce::Subscription) }

  # Filtros: status, contact_id e q (plano ou nome do cliente).
  def index
    @subscriptions = Current.account.commerce_subscriptions.includes(:payment_method).order(created_at: :desc)
    %i[status contact_id].each { |key| @subscriptions = @subscriptions.where(key => params[key]) if params[key].present? }
    @subscriptions = ::Commerce::Search.where(@subscriptions, ['name', "customer->>'name'"], params[:q]) if params[:q].present?
  end

  def show; end

  # quantity e language são opcionais (1 e o idioma da conta).
  def create
    account = Current.account
    contact = account.contacts.find(params.require(:contact_id))
    attrs = { contact: contact, created_by: Current.user,
              item: account.commerce_items.find(params.require(:item_id)), language: account_language,
              payment_method: account.commerce_payment_methods.find(params.require(:payment_method_id)) }
    @subscription = account.commerce_subscriptions.create!(attrs.merge(params.permit(:quantity, :language).compact_blank.to_h))
    render :show
  end

  # O link vai como mensagem na conversa do cliente; a conversa fica sendo a da
  # assinatura (recibos e avisos dos ciclos).
  def deliver
    conversation = Current.account.conversations.find_by!(display_id: params.require(:conversation_id))
    labels = ::Commerce::DocumentLabels.for(@subscription.language)
    content = params[:content].presence || format(labels[:subscription_message], plan: @subscription.name, url: @subscription.public_url)
    Messages::MessageBuilder.new(Current.user, conversation, { message_type: 'outgoing', content: content }).perform
    @subscription.update!(conversation: conversation, sent_at: Time.current)
    render :show
  end

  # at_period_end (padrão true): o cliente usa até o fim do que pagou.
  def cancel
    ::Commerce::SubscriptionBilling.new(@subscription).cancel!(at_period_end: params[:at_period_end].to_s != 'false')
    render :show
  rescue ::Commerce::Gateways::Error => e
    render_could_not_create_error(e.message)
  end

  private

  def fetch_subscription
    @subscription = Current.account.commerce_subscriptions.find(params[:id])
  end

  def account_language
    Current.account.locale.to_s.first(2).presence_in(::Commerce::Document::LANGUAGES) || 'es'
  end
end
