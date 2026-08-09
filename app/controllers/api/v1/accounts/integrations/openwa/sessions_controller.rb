class Api::V1::Accounts::Integrations::Openwa::SessionsController < Api::V1::Accounts::BaseController
  NAME_FORMAT = /\A[a-z0-9][a-z0-9-]{2,49}\z/

  before_action -> { check_admin_authorization? }
  before_action :ensure_feature_enabled
  before_action :ensure_configured

  rescue_from Integrations::Openwa::Client::ApiError, with: :render_openwa_error

  def index
    render json: { sessions: client.sessions, adapter_instances: slim_adapter_instances }
  end

  def create
    return render json: { error: I18n.t('errors.openwa.invalid_name') }, status: :unprocessable_entity unless valid_name?
    return render json: { error: I18n.t('errors.openwa.invalid_inbox') }, status: :unprocessable_entity unless valid_inbox?

    result = Integrations::Openwa::ProvisionService.new(
      account: Current.account,
      user: Current.user,
      name: permitted_params[:name],
      agent_bot_id: permitted_params[:agent_bot_id],
      inbox_id: permitted_params[:inbox_id]
    ).perform
    render json: result
  end

  def qr
    render json: client.qr(permitted_params[:session_id])
  end

  def start
    render json: client.start_session(permitted_params[:session_id])
  end

  def stop
    render json: client.stop_session(permitted_params[:session_id])
  end

  def logout
    render json: client.logout_session(permitted_params[:session_id])
  end

  # Remove a sessão do gateway e as instâncias do adapter escopadas a ela.
  # A inbox do Chatwoot é preservada — apagar inbox destrói conversas, e isso
  # fica a cargo do admin no fluxo normal de Settings → Inboxes.
  def destroy
    session_id = permitted_params[:session_id]
    client.adapter_instances.select { |instance| instance['sessionScope'] == session_id }.each do |instance|
      client.delete_adapter_instance(instance['instanceId'])
    end
    client.delete_session(session_id)
    head :ok
  end

  private

  def slim_adapter_instances
    instances = client.adapter_instances
    inbox_ids = instances.filter_map { |instance| instance.dig('config', 'inboxId') }
    inbox_names = Current.account.inboxes.where(id: inbox_ids).pluck(:id, :name).to_h
    instances.map do |instance|
      inbox_id = instance.dig('config', 'inboxId')
      {
        instance_id: instance['instanceId'],
        session_id: instance['sessionScope'],
        inbox_id: inbox_id,
        inbox_name: inbox_names[inbox_id],
        enabled: instance['enabled']
      }
    end
  end

  def valid_name?
    permitted_params[:name].to_s.match?(NAME_FORMAT)
  end

  def valid_inbox?
    return true if permitted_params[:inbox_id].blank?

    Current.account.inboxes.find(permitted_params[:inbox_id]).channel_type == 'Channel::Api'
  end

  # Ligado por conta no Super Admin.
  def ensure_feature_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('whatsapp_sessions')
  end

  def ensure_configured
    return if Integrations::Openwa::Client.configured?

    render json: { error: I18n.t('errors.openwa.not_configured') }, status: :unprocessable_entity
  end

  def render_openwa_error(exception)
    render json: { error: exception.message }, status: :unprocessable_entity
  end

  def client
    @client ||= Integrations::Openwa::Client.new
  end

  def permitted_params
    params.permit(:name, :agent_bot_id, :inbox_id, :session_id)
  end
end
