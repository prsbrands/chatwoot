# Comercial (flag `commerce`). Dentro deste namespace `Commerce` é o módulo do
# controller: os models são sempre `::Commerce::...`.
class Api::V1::Accounts::Commerce::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_commerce_enabled!

  private

  def ensure_commerce_enabled!
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('commerce')
  end

  # Upload pelo /upload do Chatwoot: o front manda os signed ids dos blobs.
  def blob_for(signed_id)
    ActiveStorage::Blob.find_signed!(signed_id.to_s)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    raise ActionController::BadRequest, 'invalid blob id'
  end
end
