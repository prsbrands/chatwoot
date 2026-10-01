# Uma avaliacao por rajada: o listener grava a ultima mensagem do contato e
# agenda este job com espera; so roda o job da mensagem que ainda e a ultima.
class Sales::StageAdvisorJob < ApplicationJob
  queue_as :low
  DEBOUNCE = 15.seconds

  def self.key(deal_id)
    "sales_stage_advisor:deal:#{deal_id}"
  end

  def self.schedule(deal, message)
    Redis::Alfred.set(key(deal.id), message.id, ex: 10.minutes.to_i)
    set(wait: DEBOUNCE).perform_later(deal.id, message.id)
  end

  def perform(deal_id, message_id)
    return unless Redis::Alfred.get(self.class.key(deal_id)).to_i == message_id

    deal = Sales::Deal.open.find_by(id: deal_id)
    message = Message.find_by(id: message_id)
    return if deal.nil? || message.nil?

    Sales::StageAdvisor.new(deal: deal, conversation: message.conversation).perform
  end
end
