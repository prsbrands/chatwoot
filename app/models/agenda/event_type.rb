# Tipo de agendamento: quanto dura, a folga antes e depois, a antecedência
# mínima, até quantos dias à frente se marca e quem atende por padrão. É o que
# Agenda::FreeSlots usa para oferecer horários.
class Agenda::EventType < ApplicationRecord
  self.table_name = 'agenda_event_types'

  belongs_to :account
  belongs_to :default_owner, class_name: 'User', optional: true
  has_many :appointments, class_name: 'Agenda::Appointment', dependent: :nullify, inverse_of: :event_type

  validates :name, presence: true
  validates :duration_minutes, numericality: { only_integer: true, in: 5..1440 }
  validates :buffer_before_minutes, :buffer_after_minutes, numericality: { only_integer: true, in: 0..240 }
  validates :minimum_notice_minutes, numericality: { only_integer: true, in: 0..43_200 }
  validates :booking_window_days, numericality: { only_integer: true, in: 1..365 }
end
