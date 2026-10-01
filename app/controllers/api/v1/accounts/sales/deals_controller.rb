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
    pipeline = default_pipeline
    @deal = Current.account.sales_deals.create!(
      deal_params.merge(
        pipeline: pipeline,
        stage: params[:stage_id].present? ? pipeline.stages.find(params[:stage_id]) : pipeline.first_open_stage,
        contact: contact,
        currency: deal_params[:currency].presence || ::Sales::Pipeline.currency_for(Current.account),
        conversation: params[:conversation_id].present? ? Current.account.conversations.find_by!(display_id: params[:conversation_id]) : nil,
        title: deal_params[:title].presence || contact.name.presence || contact.phone_number
      )
    )
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

  def fetch_deal
    @deal = Current.account.sales_deals.find(params[:id])
  end

  # O responsavel tem que ser da conta: find levanta 404 em vez de gravar um
  # usuario de outra conta.
  def deal_params
    permitted = params.permit(:title, :value_cents, :currency, :assignee_id)
    Current.account.users.find(permitted[:assignee_id]) if permitted[:assignee_id].present?
    permitted
  end
end
