class Api::V1::Accounts::AiEvolution::SuggestionsController < Api::V1::Accounts::AiEvolution::BaseController
  STATUSES = %w[pending applied rejected].freeze
  LIMIT = 200

  before_action :fetch_suggestion, only: [:show, :update, :apply, :reject, :undo]
  before_action -> { check_authorization(@suggestion || ::AiEvolution::Suggestion) }

  # As pendentes com mais evidência primeiro; aplicadas e recusadas, as
  # decididas por último primeiro.
  def index
    status = params[:status].presence || 'pending'
    raise ActionController::BadRequest, 'invalid status' unless STATUSES.include?(status)

    scope = Current.account.ai_evolution_suggestions.where(status: status)
    scope = scope.where(kind: params[:kind]) if params[:kind].present?
    scope = scope.where(persona_id: params[:persona_id]) if params[:persona_id].present?
    @suggestions = (status == 'pending' ? scope.queue : scope.order(updated_at: :desc)).limit(LIMIT)
  end

  def show; end

  # Editar antes de aplicar: o texto e o título da proposta pendente.
  def update
    @suggestion.update!(params.permit(:title, :content).to_h.merge(edited: true)) if @suggestion.pending?
    render :show
  end

  def apply
    ::AiEvolution::Applier.new(@suggestion, Current.user).apply!(title: params[:title], content: params[:content])
    render :show
  end

  def reject
    unless @suggestion.pending?
      @suggestion.errors.add(:base, 'only pending suggestions can be rejected')
      raise ActiveRecord::RecordInvalid, @suggestion
    end

    @suggestion.update!(status: :rejected, rejected_at: Time.current, rejected_by: Current.user, reject_reason: params[:reason].to_s.truncate(500))
    render :show
  end

  def undo
    ::AiEvolution::Applier.new(@suggestion, Current.user).undo!
    render :show
  end

  # O número do menu.
  def pending_count
    render json: { count: Current.account.ai_evolution_suggestions.pending.count }
  end

  def progress
    render json: { payload: ::AiEvolution::Progress.new(Current.account).weeks }
  end

  private

  def fetch_suggestion
    @suggestion = Current.account.ai_evolution_suggestions.find(params[:id])
  end
end
