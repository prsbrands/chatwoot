# == Schema Information
#
# Table name: twilio_voice_calls
#
#  id           :bigint           not null, primary key
#  call_sid     :string           not null
#  from_number  :string
#  phone_number :string           not null
#  status       :string           default("ringing"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_twilio_voice_calls_on_call_sid  (call_sid) UNIQUE
#

# Registro de cada chamada roteada, para a tela mostrar o que aconteceu e para
# dar o que ler quando uma ligação não chega a quem devia.
class TwilioVoiceCall < ApplicationRecord
  belongs_to :account

  validates :call_sid, presence: true, uniqueness: true
end
