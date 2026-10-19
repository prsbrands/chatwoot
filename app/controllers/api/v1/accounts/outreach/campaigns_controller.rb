class Api::V1::Accounts::Outreach::CampaignsController < Api::V1::Accounts::Outreach::BaseController
  LIMIT = 100
  RECIPIENTS_PER_PAGE = 100
  PACING_PARAMS = [:window_start, :window_end, :interval_min, :interval_max, :max_per_hour, :max_per_day, :batch_size, :batch_pause_min,
                   :batch_pause_max, { days: [] }].freeze
  GUESSES = { 'phone' => /phone|tel|cel|whats|mobile|movil|fone/i, 'name' => /name|nombre|nome/i, 'company' => /company|empresa/i }.freeze

  before_action :fetch_campaign, except: [:index, :create, :attention_count, :preview_import]
  before_action -> { check_authorization(@campaign || ::Outreach::Campaign) }

  def index
    @campaigns = Current.account.outreach_campaigns.includes(:inbox, :created_by).order(id: :desc).limit(LIMIT)
  end

  def show; end

  def create
    @campaign = Current.account.outreach_campaigns.create!(campaign_params.merge(created_by: Current.user))
    render :show
  end

  # Editar o texto e o ritmo volta a campanha pronta para rascunho: a lista tem de
  # ser preparada de novo.
  def update
    reopen!
    @campaign.update!(campaign_params)
    render :show
  end

  def destroy
    unless @campaign.draft? || @campaign.cancelled?
      @campaign.errors.add(:status, 'only draft or cancelled campaigns can be deleted')
      raise ActiveRecord::RecordInvalid, @campaign
    end

    @campaign.destroy!
    head :ok
  end

  # A lista da campanha: contatos do CRM (filtros) ou um arquivo com o mapeamento
  # das colunas. Troca a lista anterior.
  def audience
    reopen!
    params[:source] == 'crm' ? crm_audience : import_audience
    render :show
  rescue ::Outreach::Sheet::Invalid => e
    render_could_not_create_error(e.message)
  end

  # A campanha volta com as contagens (por motivo de exclusão) nas métricas.
  def prepare
    ::Outreach::Prepare.new(@campaign).perform
    render :show
  end

  def start
    @campaign.start!
    render :show
  end

  def pause
    @campaign.transition_to!(:paused, paused_at: Time.current, paused_reason: 'manual')
    render :show
  end

  def cancel
    ActiveRecord::Base.transaction do
      @campaign.transition_to!(:cancelled)
      @campaign.recipients.where(status: [:pending, :sending]).update_all(status: ::Outreach::Recipient.statuses[:cancelled]) # rubocop:disable Rails/SkipsModelValidations
    end
    render :show
  end

  def test
    phone = ::Outreach::Phone.normalize(params.require(:phone), country: params[:country].presence || ::Outreach::Phone::DEFAULT_COUNTRY)
    return render_could_not_create_error('invalid phone') if phone.nil?

    bubbles = ::Outreach::TestSend.new(@campaign, phone).perform
    return render_could_not_create_error('the inbox has no WhatsApp session') if bubbles.nil?

    render json: { bubbles: bubbles }
  end

  # Lê o arquivo e devolve as colunas, as primeiras linhas e um palpite do
  # mapeamento, para a tela montar o passo de colunas sem guardar nada.
  def preview_import
    sheet = ::Outreach::Sheet.read(params.require(:file))
    render json: { headers: sheet.headers, sample: sheet.rows.first(5), total: sheet.rows.size,
                   mapping: GUESSES.transform_values { |pattern| sheet.headers.find { |header| header.match?(pattern) } } }
  rescue ::Outreach::Sheet::Invalid => e
    render_could_not_create_error(e.message)
  end

  def recipients
    scope = @campaign.recipients.order(:id)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(excluded_reason: params[:reason]) if params[:reason].present?
    @page = [params[:page].to_i, 1].max
    @count = scope.count
    @recipients = scope.offset((@page - 1) * RECIPIENTS_PER_PAGE).limit(RECIPIENTS_PER_PAGE)
  end

  # O número do menu: campanhas que o sistema pausou (sessão caída, falhas).
  def attention_count
    render json: { count: Current.account.outreach_campaigns.paused.where.not(paused_reason: 'manual').count }
  end

  private

  def fetch_campaign
    @campaign = Current.account.outreach_campaigns.find(params[:id])
  end

  def reopen!
    @campaign.transition_to!(:draft) if @campaign.ready?
    return if @campaign.editable?

    @campaign.errors.add(:status, 'only draft campaigns can be edited')
    raise ActiveRecord::RecordInvalid, @campaign
  end

  def crm_audience
    filters = params.fetch(:filters, {}).permit(:label, :stage_id, :inbox_id).to_h
    ::Outreach::Audience.new(@campaign, filters).perform
  end

  def import_audience
    sheet = ::Outreach::Sheet.read(params.require(:file))
    mapping = params.require(:mapping).permit(:phone, :name, :company).to_h
    raise ::Outreach::Sheet::Invalid, 'map the phone column' unless sheet.headers.include?(mapping['phone'])

    ::Outreach::Importer.new(@campaign, sheet, mapping, country: params[:country].presence || ::Outreach::Phone::DEFAULT_COUNTRY).perform
  end

  def campaign_params
    params.permit(:name, :inbox_id, :cold, :opt_out_footer, :attribution_hours, variants: [], pacing: PACING_PARAMS).to_h
  end
end
