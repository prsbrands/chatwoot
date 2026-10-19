# Uma volta da cadeia de envio da campanha: o Outreach::Dispatcher manda no
# máximo uma pessoa e devolve quando acordar de novo (o intervalo, a pausa do
# lote, a abertura da janela). Só o `wake_at` mais recente da campanha vale: um
# acordar repetido ou atrasado vê que não é o atual e sai, para a cadeia nunca
# se multiplicar.
class Outreach::SendNextJob < ApplicationJob
  queue_as :low

  def perform(campaign, wake)
    return unless campaign.running? && campaign.wake_at && (campaign.wake_at.to_f - wake).abs < 1

    next_wake = Outreach::Dispatcher.new(campaign).run
    campaign.schedule_wake!(next_wake) if next_wake
  end
end
