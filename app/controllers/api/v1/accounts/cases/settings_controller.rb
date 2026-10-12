# Configuração dos casos na conta: por enquanto, o prefixo do número.
class Api::V1::Accounts::Cases::SettingsController < Api::V1::Accounts::Cases::BaseController
  PREFIX = /\A[A-Z0-9]{1,8}\z/.freeze

  before_action -> { check_authorization(::Cases::Type) }, only: :update

  def show; end

  def update
    prefix = params.require(:prefix).to_s.strip.upcase
    return render json: { error: 'prefix must be 1 to 8 letters or digits' }, status: :unprocessable_entity unless prefix.match?(PREFIX)

    Current.account.update!(cases_prefix: prefix)
    render :show
  end
end
