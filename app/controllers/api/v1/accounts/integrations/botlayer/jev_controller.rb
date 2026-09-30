# Cartão do Jev (TypeSafe) em Settings → Integrations → AI Providers.
#
# A chave e o estado de cada atividade ficam em bot_account_settings, a linha
# que o Guard do n8n já lê a cada mensagem — é de lá que o workflow decide o
# que perguntar ao Jev e o que fazer com a resposta. Este controller é o único
# que escreve essas colunas.
class Api::V1::Accounts::Integrations::Botlayer::JevController < Api::V1::Accounts::Integrations::Botlayer::BaseController
  MODELS_URL = 'https://api.typesafe.ai/v1/models'.freeze
  ACTIVITIES = %w[knowledge model_routing no_reply human_request mood opt_out manipulation reply_review followup].freeze
  STATES = %w[observing deciding off].freeze
  MAX_REVIEW_RULES = 10
  # Sugestao de etiqueta e prioridade e condicoes por IA nas automacoes (codigo
  # do upstream, Captain::JevClient) ficam atras desta flag da conta. Quem liga
  # e desliga e o cartao, para ela nunca ficar ligada sem chave e consentimento.
  TEAM_FEATURE = 'captain_classifier'.freeze

  def show
    render_card
  end

  def update
    config = settings['jev'] || {}
    config['activities'] = (config['activities'] || {}).merge(activity_params) if params[:activities].present?
    config['review_rules'] = review_rules_param if params.key?(:review_rules)
    config['consent'] ||= consent if ActiveModel::Type::Boolean.new.cast(params[:consent])
    config['enabled'] = enable!(config) if params.key?(:enabled)

    client.upsert_account_settings(account_id, { jev: config })
    toggle_team_feature(config)
    render_card
  end

  # A chave só é gravada depois de a TypeSafe aceitá-la: GET /v1/models não
  # gasta token e responde 401/403 para chave ruim.
  def key
    api_key = params.require(:api_key).to_s.strip
    check_key!(api_key)
    client.upsert_account_settings(account_id, { jev_api_key: api_key, jev_key_checked_at: Time.current })
    render_card
  end

  # Sem chave o Jev não tem como rodar; desligar junto evita um "ligado" que
  # só falha.
  def destroy_key
    config = (settings['jev'] || {}).merge('enabled' => false)
    client.upsert_account_settings(account_id, { jev_api_key: nil, jev_key_checked_at: nil, jev: config })
    Current.account.disable_features!(TEAM_FEATURE)
    render_card
  end

  private

  def required_feature
    'ai_providers'
  end

  def account_id
    Current.account.id
  end

  def settings
    @settings ||= client.account_settings(account_id)
  end

  def render_card
    row = client.account_settings(account_id)
    config = row['jev'] || {}
    render json: {
      has_key: row['jev_api_key'].present?,
      key_checked_at: row['jev_key_checked_at'],
      enabled: config['enabled'] == true,
      consent: config['consent'],
      activities: ACTIVITIES.index_with { |id| config.dig('activities', id) || 'observing' },
      review_rules: config['review_rules'] || [],
      team: Current.account.feature_enabled?(TEAM_FEATURE),
      summary: client.jev_summary(account_id)
    }
  end

  def enable!(config)
    enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
    return false unless enabled
    raise Integrations::Botlayer::Client::ApiError, I18n.t('errors.botlayer.jev_needs_key') if settings['jev_key_checked_at'].blank?
    raise Integrations::Botlayer::Client::ApiError, I18n.t('errors.botlayer.jev_needs_consent') if config['consent'].blank?

    true
  end

  def toggle_team_feature(config)
    if config['enabled'] == false
      Current.account.disable_features!(TEAM_FEATURE)
    elsif params.key?(:team)
      team = ActiveModel::Type::Boolean.new.cast(params[:team]) && config['enabled']
      team ? Current.account.enable_features!(TEAM_FEATURE) : Current.account.disable_features!(TEAM_FEATURE)
    end
  end

  def consent
    { 'user_id' => Current.user.id, 'name' => Current.user.name, 'at' => Time.current.iso8601 }
  end

  def activity_params
    params.require(:activities).permit(*ACTIVITIES).to_h.select { |_, state| STATES.include?(state) }
  end

  def review_rules_param
    Array(params[:review_rules]).map { |rule| rule.to_s.strip }.compact_blank.first(MAX_REVIEW_RULES)
  end

  def check_key!(api_key)
    response = HTTParty.get(MODELS_URL, headers: { 'Authorization' => "Bearer #{api_key}" }, timeout: 10)
    return if response.success?

    message = if [401, 403].include?(response.code)
                I18n.t('errors.botlayer.jev_key_rejected')
              else
                I18n.t('errors.botlayer.jev_key_check_failed', status: response.code)
              end
    raise Integrations::Botlayer::Client::ApiError, message
  end
end
