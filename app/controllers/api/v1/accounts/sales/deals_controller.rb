class Api::V1::Accounts::Sales::DealsController < Api::V1::Accounts::Sales::BaseController
  before_action -> { check_authorization(::Sales::Deal) }
  before_action :fetch_deal, only: [:show, :update, :destroy]

  # Sem filtro: os negocios do funil (o Kanban). Com contact_id: os do contato
  # (o card na conversa).
  def index
    deals = Current.account.sales_deals.includes(:contact, :conversation, :assignee, :insight)
    @deals = if params[:contact_id].present?
               deals.where(contact_id: params[:contact_id]).order(created_at: :desc)
             else
               deals.where(pipeline: params[:pipeline_id].presence || default_pipeline.id).order(stage_changed_at: :desc)
             end
  end

  def show; end

  def create
    contact = Current.account.contacts.find(params.require(:contact_id))
    @deal = Current.account.sales_deals.create!(new_deal_attributes(contact))
  end

  def update
    ActiveRecord::Base.transaction do
      @deal.update!(deal_params)
      @deal.dismiss_suggestion! if ActiveModel::Type::Boolean.new.cast(params[:dismiss_suggestion])
      if params[:stage_id].present?
        stage = ::Sales::Stage.where(account_id: Current.account.id).find(params[:stage_id])
        @deal.move_to!(stage, actor: Current.user, lost_reason: params[:lost_reason], reason: params[:reason])
      end
    end
  end

  def destroy
    @deal.destroy!
    head :ok
  end

  private

  def new_deal_attributes(contact)
    pipeline = default_pipeline
    deal_params.merge(
      pipeline: pipeline,
      stage: params[:stage_id].present? ? pipeline.stages.find(params[:stage_id]) : pipeline.first_open_stage,
      contact: contact,
      conversation: requested_conversation,
      title: deal_params[:title].presence || contact.name.presence || contact.phone_number,
      currency: deal_params[:currency].presence || ::Sales::Pipeline.currency_for(Current.account)
    )
  end

  # O painel manda o display_id, o mesmo da URL da conversa.
  def requested_conversation
    return if params[:conversation_id].blank?

    Current.account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def fetch_deal
    @deal = Current.account.sales_deals.find(params[:id])
  end

  # O responsavel tem que ser da conta: find levanta 404 em vez de gravar um
  # usuario de outra conta.
  def deal_params
    @deal_params ||= params.permit(:title, :value_cents, :currency, :assignee_id).tap do |permitted|
      Current.account.users.find(permitted[:assignee_id]) if permitted[:assignee_id].present?
    end
  end
end
