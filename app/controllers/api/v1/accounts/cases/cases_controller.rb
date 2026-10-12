class Api::V1::Accounts::Cases::CasesController < Api::V1::Accounts::Cases::BaseController
  PER_PAGE = 100
  FILTERS = %w[active resolved canceled all].freeze
  ACTIVE_ORDER = Arel.sql('cases_cases.due_at ASC NULLS LAST, cases_cases.created_at ASC')
  # Ids que têm que ser da conta: o find levanta 404 em vez de gravar o de outra.
  OWNED = { type_id: :cases_types, contact_id: :contacts, deal_id: :sales_deals, assignee_id: :users, team_id: :teams }.freeze

  before_action :fetch_case, except: [:index, :create, :overdue_count]
  before_action -> { check_authorization(@case || ::Cases::Case) }

  # Os ativos por prazo (sem prazo no fim); resolvidos e cancelados, os mais
  # recentes primeiro.
  def index
    cases = filtered_cases
    @total = cases.count
    order = params[:status].in?(%w[resolved canceled]) ? { updated_at: :desc } : ACTIVE_ORDER
    @cases = cases.order(order).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show; end

  def create
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id]) if params[:conversation_id].present?
    @case = ::Cases::CaseFlow.open!(Current.account, case_params, actor: Current.user,
                                                                  source: conversation ? :conversation : :manual, conversation: conversation)
    render :show
  end

  def update
    flow.update!(case_params)
    render :show
  end

  def destroy
    @case.destroy!
    head :ok
  end

  %w[start wait_customer reopen].each do |action|
    define_method(action) do
      flow.transition!(action)
      render :show
    end
  end

  def resolve
    flow.transition!('resolve', outcome: params[:outcome], resolution: params[:resolution])
    render :show
  end

  def cancel
    flow.transition!('cancel', resolution: params[:resolution])
    render :show
  end

  def note
    flow.note!(params.require(:body))
    render :show
  end

  def link_conversation
    flow.link_conversation!(Current.account.conversations.find_by!(display_id: params.require(:conversation_id)))
    render :show
  end

  # O número vermelho do menu: atrasados da conta e os meus.
  def overdue_count
    overdue = Current.account.cases.overdue
    render json: { count: overdue.count, mine: overdue.where(assignee_id: Current.user.id).count }
  end

  private

  def fetch_case
    @case = Current.account.cases.find(params[:id])
  end

  def flow
    ::Cases::CaseFlow.new(@case, actor: Current.user)
  end

  def page
    [params[:page].to_i, 1].max
  end

  def filtered_cases
    cases = status_scope(Current.account.cases.includes(:type, :assignee, :contact))
    cases = cases.where(params.permit(:type_id, :priority, :contact_id).to_h.compact_blank)
    cases = cases.where(assignee_id: assignee_filter) if params[:assignee_id].present?
    cases = cases.overdue if ActiveModel::Type::Boolean.new.cast(params[:overdue])
    narrowed(cases)
  end

  def narrowed(cases)
    cases = by_conversation(cases) if params[:conversation_id].present?
    params[:q].present? ? search(cases) : cases
  end

  def status_scope(cases)
    status = params[:status].presence || 'active'
    raise ActionController::BadRequest, 'invalid status' unless FILTERS.include?(status) || ::Cases::Case.statuses.key?(status)

    case status
    when 'all' then cases
    when 'active' then cases.active
    else cases.where(status: status)
    end
  end

  def assignee_filter
    { 'me' => Current.user.id, 'none' => nil }.fetch(params[:assignee_id], params[:assignee_id])
  end

  def by_conversation(cases)
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    cases.where(id: ::Cases::CaseConversation.where(conversation_id: conversation.id).select(:case_id))
  end

  def search(cases)
    ::Commerce::Search.where(cases.joins(:contact), %w[cases_cases.number cases_cases.title contacts.name], params[:q])
  end

  def case_params
    @case_params ||= params.permit(
      :title, :description, :type_id, :priority, :assignee_id, :team_id, :due_at, :contact_id, :deal_id, field_values: {}
    ).tap do |permitted|
      OWNED.each { |key, records| Current.account.public_send(records).find(permitted[key]) if permitted[key].present? }
      permitted[:field_values] = permitted[:field_values].to_h if permitted.key?(:field_values)
    end
  end
end
