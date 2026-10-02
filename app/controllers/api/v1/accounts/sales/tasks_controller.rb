class Api::V1::Accounts::Sales::TasksController < Api::V1::Accounts::Sales::BaseController
  DONE_LIMIT = 100

  before_action :fetch_task, only: [:update, :destroy]
  before_action -> { check_authorization(@task || ::Sales::Task) }

  # Pendentes por prazo (sem prazo no fim); concluídas, as mais recentes. Filtra
  # por negócio, contato ou responsável ("me" = quem pede).
  def index
    @tasks = if params[:status] == 'done'
               filtered_tasks.done.order(completed_at: :desc).limit(DONE_LIMIT)
             else
               filtered_tasks.pending.order(Arel.sql('due_at ASC NULLS LAST, created_at ASC'))
             end
  end

  def create
    @task = Current.account.sales_tasks.create!(
      task_params.with_defaults(assignee_id: Current.user.id).merge(created_by: Current.user)
    )
    render :show
  end

  def update
    @task.update!(task_params)
    if params.key?(:completed)
      ActiveModel::Type::Boolean.new.cast(params[:completed]) ? @task.complete!(Current.user) : @task.reopen!
    end
    render :show
  end

  def destroy
    @task.destroy!
    head :ok
  end

  private

  def fetch_task
    @task = Current.account.sales_tasks.find(params[:id])
  end

  def filtered_tasks
    tasks = Current.account.sales_tasks.includes(:assignee, :contact, deal: [:stage, :conversation])
    tasks = tasks.where(deal_id: params[:deal_id]) if params[:deal_id].present?
    tasks = tasks.where(contact_id: params[:contact_id]) if params[:contact_id].present?
    tasks = tasks.where(assignee_id: assignee_filter) if params[:assignee_id].present?
    tasks
  end

  def assignee_filter
    params[:assignee_id] == 'me' ? Current.user.id : params[:assignee_id]
  end

  # Negócio, contato e responsável têm que ser da conta: o find levanta 404 em
  # vez de gravar o de outra conta.
  def task_params
    @task_params ||= params.permit(:title, :notes, :due_at, :deal_id, :contact_id, :assignee_id).tap do |permitted|
      Current.account.sales_deals.find(permitted[:deal_id]) if permitted[:deal_id].present?
      Current.account.contacts.find(permitted[:contact_id]) if permitted[:contact_id].present?
      Current.account.users.find(permitted[:assignee_id]) if permitted[:assignee_id].present?
    end
  end
end
