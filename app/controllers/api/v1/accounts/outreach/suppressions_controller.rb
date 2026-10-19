class Api::V1::Accounts::Outreach::SuppressionsController < Api::V1::Accounts::Outreach::BaseController
  LIMIT = 500

  before_action -> { check_authorization(::Outreach::Suppression) }

  def index
    @suppressions = Current.account.outreach_suppressions.order(id: :desc).limit(LIMIT)
  end

  # Vários números de uma vez (um por linha, vírgula ou ponto e vírgula). Os que
  # não viram telefone voltam em `invalid`.
  def create
    render json: ::Outreach::Suppression.add_all(Current.account, params.require(:phones).to_s,
                                                 country: params[:country].presence || ::Outreach::Phone::DEFAULT_COUNTRY,
                                                 reason: params[:reason].to_s.truncate(200), user: Current.user)
  end

  def destroy
    Current.account.outreach_suppressions.find(params[:id]).destroy!
    head :ok
  end
end
