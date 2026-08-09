# == Schema Information
#
# Table name: twilio_voice_routes
#
#  id               :bigint           not null, primary key
#  answer_mode      :string           default("human"), not null
#  bot_persona_slug :string
#  destination      :string
#  destination_type :string           not null
#  enabled          :boolean          default(TRUE), not null
#  no_answer_action :string           default("hangup"), not null
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

# Para quem toca uma chamada que entra num número Twilio da conta, e o que
# acontece quando ninguém atende.
class TwilioVoiceRoute < ApplicationRecord
  DESTINATION_TYPES = %w[sip pstn].freeze
  ANSWER_MODES = %w[human bot].freeze
  NO_ANSWER_ACTIONS = %w[hangup bot].freeze

  belongs_to :account

  validates :phone_number, presence: true, uniqueness: { scope: :account_id }
  validates :destination_type, inclusion: { in: DESTINATION_TYPES }
  # Só há destino a exigir quando é um humano que atende.
  validates :destination, presence: true, unless: :bot_answers_first?
  validates :ring_timeout, numericality: { greater_than: 4, less_than_or_equal_to: 120 }
  validates :answer_mode, inclusion: { in: ANSWER_MODES }
  validates :no_answer_action, inclusion: { in: NO_ANSWER_ACTIONS }
  # Rota que manda a chamada para o bot sem dizer qual persona não tem o que
  # responder — e o erro só apareceria com o cliente na linha.
  validates :bot_persona_slug, presence: true, if: :bot_anywhere?

  def sip?
    destination_type == 'sip'
  end

  def bot_answers_first?
    answer_mode == 'bot'
  end

  def bot_on_no_answer?
    no_answer_action == 'bot'
  end

  private

  def bot_anywhere?
    bot_answers_first? || bot_on_no_answer?
  end
end
