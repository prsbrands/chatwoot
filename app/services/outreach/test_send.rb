# "Enviar teste para mim": manda a mensagem da campanha, já com as variáveis de
# uma pessoa de exemplo, para um número da equipe. Não entra na lista nem nas
# métricas, e não passa pelo ritmo (é uma mensagem só, para quem sabe que vem).
class Outreach::TestSend
  def initialize(campaign, phone)
    @campaign = campaign
    @phone = phone
  end

  # As bolhas enviadas, ou nil quando a inbox não tem sessão.
  def perform
    session = Integrations::Openwa::Client.new.session_for_inbox(@campaign.account_id, @campaign.inbox_id)
    return if session.nil?

    bubbles = Outreach::Message.new(@campaign, sample).bubbles
    bubbles.each_with_index do |bubble, index|
      Integrations::Openwa::Client.new.send_text(session, "#{@phone.delete('+')}@c.us", bubble)
      sleep(rand(2.0..4.0)) unless index == bubbles.size - 1
    end
    bubbles
  end

  private

  # A primeira pessoa da lista, para o teste mostrar o que ela receberia.
  def sample
    person = @campaign.recipients.order(:id).first || Outreach::Recipient.new(name: 'Test Person')
    person.tap { |item| item.variant = 0 }
  end
end
