# A IA marcando na conversa: o tipo que ela pode oferecer (EventType.for_ai),
# os horários livres dele nos próximos dias e a marcação de um deles. Os
# horários são conferidos de novo na hora de marcar: entre a oferta e o "pode
# ser às 10h" do cliente, outra pessoa pode ter ocupado o horário.
class Agenda::AiBooking
  DAYS_AHEAD = 14
  MAX_SLOTS = 40

  class SlotTaken < StandardError
    attr_reader :alternatives

    def initialize(alternatives)
      @alternatives = alternatives
      super('slot taken')
    end
  end

  attr_reader :event_type

  def initialize(account)
    @account = account
    @event_type = account.agenda_event_types.for_ai.first
  end

  def owner
    @event_type.default_owner
  end

  def zone
    @zone ||= ::Agenda::Availability.find_by(account: @account, user: owner)&.zone || Time.zone
  end

  def slots
    @slots ||= ::Agenda::FreeSlots.new(event_type: @event_type, owner: owner, from: Time.current, to: DAYS_AHEAD.days.from_now)
                                  .call.slots.first(MAX_SLOTS)
  end

  def book!(conversation, starts_at)
    raise SlotTaken, slots.reject { |slot| slot < starts_at }.first(3) unless slots.any? { |slot| slot.to_i == starts_at.to_i }

    appointment = create_appointment(conversation, starts_at)
    conversation.messages.create!(account: @account, inbox: conversation.inbox, message_type: :activity,
                                  content: I18n.t('agenda.ai_booked', type: @event_type.name, owner: owner.available_name,
                                                                      when: I18n.l(starts_at.in_time_zone(zone), format: :long)))
    appointment
  end

  private

  def create_appointment(conversation, starts_at)
    contact = conversation.contact
    @account.agenda_appointments.create!(
      event_type: @event_type, owner: owner, contact: contact, conversation: conversation,
      deal: @account.sales_deals.open.find_by(contact: contact),
      title: "#{@event_type.name} — #{contact.name}", location: @event_type.location,
      starts_at: starts_at, ends_at: starts_at + @event_type.duration_minutes.minutes,
      status: @event_type.requires_confirmation ? :pending : :confirmed
    )
  end
end
