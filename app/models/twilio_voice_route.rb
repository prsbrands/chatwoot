# == Schema Information
#
# Table name: twilio_voice_routes
#
#  id               :bigint           not null, primary key
#  destination      :string           not null
#  destination_type :string           not null
#  enabled          :boolean          default(TRUE), not null
#  phone_number     :string           not null
#  ring_timeout     :integer          default(20), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#
# Indexes
#
#  index_twilio_voice_routes_on_account_id_and_phone_number  (account_id,phone_number) UNIQUE
#

# Para quem toca uma chamada que entra num número Twilio da conta.
class TwilioVoiceRoute < ApplicationRecord
  DESTINATION_TYPES = %w[sip pstn].freeze

  belongs_to :account

  validates :phone_number, presence: true, uniqueness: { scope: :account_id }
  validates :destination_type, inclusion: { in: DESTINATION_TYPES }
  validates :destination, presence: true
  validates :ring_timeout, numericality: { greater_than: 4, less_than_or_equal_to: 120 }

  def sip?
    destination_type == 'sip'
  end
end
