# == Schema Information
#
# Table name: twilio_credentials
#
#  id          :bigint           not null, primary key
#  account_sid :string           not null
#  auth_token  :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_twilio_credentials_on_account_id  (account_id) UNIQUE
#

# Credenciais do Twilio da conta, usadas para descobrir os números disponíveis e
# provisionar canais. Cada inbox de Twilio guarda a sua própria cópia (é assim
# que o Chatwoot funciona); estas são a fonte a partir da qual elas nascem.
class TwilioCredential < ApplicationRecord
  belongs_to :account

  encrypts :auth_token if Chatwoot.encryption_configured?

  validates :account_sid, presence: true, format: { with: /\AAC[0-9a-fA-F]{32}\z/, message: 'must be a Twilio Account SID (AC…)' }
  validates :auth_token, presence: true
  validates :account_id, uniqueness: true
end
