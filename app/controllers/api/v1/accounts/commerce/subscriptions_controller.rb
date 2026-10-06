# Assinaturas da conta. Criar copia o plano (item com billing_interval) e o
# cliente; o link /s/:token vai pela conversa e o cliente assina pelo provedor.
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

  def create
    item = Current.account.commerce_items.find(params.require(:item_id))
    method = Current.account.commerce_payment_methods.find(params.require(:payment_method_id))
    contact = Current.account.contacts.find(params.require(:contact_id))
    @subscription = Current.account.commerce_subscriptions.create!(
      contact: contact, item: item, name: item.name, unit_price: item.price, currency: item.currency, interval: item.billing_interval,
      quantity: params[:quantity].presence || 1, payment_method: method, provider: method.provider, customer: customer_for(contact),
      conversation: params[:conversation_id].presence && Current.account.conversations.find_by!(display_id: params[:conversation_id]),
      deal: Current.account.sales_deals.open.find_by(contact: contact), created_by: Current.user,
      language: params[:language].presence || Current.account.locale.to_s.first(2).presence_in(::Commerce::Document::LANGUAGES) || 'es'
    )
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

  # Os dados fiscais lembrados do último documento (billing_*) vão junto.
  def customer_for(contact)
    billing = (contact.additional_attributes || {}).slice('billing_tax_id_label', 'billing_tax_id', 'billing_address')
                                                   .transform_keys { |key| key.delete_prefix('billing_') }
    { 'name' => contact.name, 'email' => contact.email, 'phone' => contact.phone_number }.merge(billing).compact_blank
  end
end
