# Dados da empresa (uma linha por conta). O logo vem do /upload como blob_id;
# remove_logo tira o logo.
class Api::V1::Accounts::Commerce::ProfilesController < Api::V1::Accounts::Commerce::BaseController
  before_action :fetch_profile
  before_action -> { check_authorization(@profile) }

  def show; end

  def update
    @profile.assign_attributes(profile_params)
    @profile.logo.attach(blob_for(params[:logo_blob_id])) if params[:logo_blob_id].present?
    @profile.logo.purge_later if ActiveModel::Type::Boolean.new.cast(params[:remove_logo])
    @profile.save!
    render :show
  end

  private

  def fetch_profile
    @profile = ::Commerce::Profile.for(Current.account)
  end

  def profile_params
    params.permit(:trade_name, :legal_name, :tax_id_label, :tax_id, :address, :phone, :whatsapp, :email, :website,
                  :default_currency, :default_terms, :footer)
  end
end
