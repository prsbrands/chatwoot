# A tela Radar: negócios abertos em risco, crítico primeiro (Sales::Radar).
class Api::V1::Accounts::Sales::RadarController < Api::V1::Accounts::Sales::BaseController
  before_action -> { check_authorization(::Sales::Deal) }

  def index
    @rows = ::Sales::Radar.new(Current.account).rows
  end
end
