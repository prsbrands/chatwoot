# A conta Google de uma pessoa nesta conta do Chatwoot. Os tokens ficam
# cifrados (Active Record Encryption, como os do Instagram e do WhatsApp).
class Agenda::GoogleConnection < ApplicationRecord
  self.table_name = 'agenda_google_connections'

  belongs_to :account
  belongs_to :user

  encrypts :access_token if Chatwoot.encryption_configured?
  encrypts :refresh_token if Chatwoot.encryption_configured?

  enum :status, { healthy: 0, reauthorization_required: 1 }

  validates :email, presence: true
  validates :user_id, uniqueness: { scope: :account_id }
end
