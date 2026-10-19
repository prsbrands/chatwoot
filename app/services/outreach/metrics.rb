# O funil da campanha. Enviadas, respostas e pedidos de parada saem dos carimbos
# e do estado, e cada taxa tem o próprio denominador: misturar tudo numa "taxa
# de sucesso" apaga a distinção que diz o que consertar (lista suja, texto,
# oferta). Quem foi excluído nunca entrou na corrida e fica fora das taxas. O
# WhatsApp por QR não devolve entregue/lida para o Chatwoot, então o funil para
# em enviada e respondida.
class Outreach::Metrics
  def initialize(campaign)
    @campaign = campaign
  end

  def perform
    counts = @campaign.recipients.group(:status).count
    replied = counts['replied'].to_i + counts['opted_out'].to_i
    sent = @campaign.recipients.where.not(sent_at: nil).count
    funnel(counts, sent, replied).merge(rates(counts, sent, replied))
  end

  private

  def funnel(counts, sent, replied)
    {
      total: counts.values.sum,
      excluded: counts['excluded'].to_i,
      excluded_by_reason: @campaign.recipients.excluded.group(:excluded_reason).count,
      pending: counts['pending'].to_i + counts['sending'].to_i,
      sent: sent,
      replied: replied,
      opted_out: counts['opted_out'].to_i,
      failed: counts['failed'].to_i,
      cancelled: counts['cancelled'].to_i
    }
  end

  def rates(counts, sent, replied)
    { reply_rate: rate(replied, sent), failure_rate: rate(counts['failed'].to_i, sent + counts['failed'].to_i) }
  end

  def rate(numerator, denominator)
    return if denominator.zero?

    (numerator.to_f / denominator).round(3)
  end
end
