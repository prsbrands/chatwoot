# A jornada semanal de uma pessoa, no fuso dela: em que dias e faixas ela
# atende. Sem jornada, ninguém oferece horário dela (marcar à mão continua).
class Agenda::Availability < ApplicationRecord
  self.table_name = 'agenda_availabilities'
  TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :account
  belongs_to :user

  validates :user_id, uniqueness: { scope: :account_id }
  validates :time_zone, inclusion: { in: TZInfo::Timezone.all_identifiers }
  validate :windows_shape

  def zone
    ActiveSupport::TimeZone[time_zone]
  end

  # Faixas do dia da semana (0 = domingo), como horários no fuso da pessoa.
  def windows_on(date)
    windows.select { |window| window['day'] == date.wday }.map do |window|
      [zone.parse("#{date} #{window['start']}"), zone.parse("#{date} #{window['end']}")]
    end
  end

  private

  def windows_shape
    errors.add(:windows, :invalid) unless windows.is_a?(Array) && windows.all? { |window| valid_window?(window) }
  end

  def valid_window?(window)
    window.is_a?(Hash) && (0..6).cover?(window['day']) &&
      TIME.match?(window['start'].to_s) && TIME.match?(window['end'].to_s) && window['start'] < window['end']
  end
end
