# O webhook da mensagem leva o endereço direto do arquivo (download_url), e não
# o que redireciona (file_url, o do painel). O adaptador do OpenWA, por
# segurança contra SSRF, não segue redirecionamento e descartava toda mensagem
# com anexo enviada do Chatwoot para o WhatsApp por QR (visto em 05/10 com o PDF
# de um orçamento). O próprio Attachment diz para usar download_url com
# serviços externos.
#
# Casos (1.23.1): a mensagem do cliente numa conversa com caso esperando a
# resposta dele vai para o caso pelo Cases::CustomerReplyJob, com texto ou só
# anexo (a foto que a equipe pediu chega sem texto, e o bot não olha mensagem
# sem texto). Vale também em caixa sem bot e com a conversa atribuída.
module CortexgenMessage
  def webhook_data
    data = super
    return data if data[:attachments].blank?

    direct = attachments.index_by(&:id)
    data[:attachments] = data[:attachments].map do |attachment|
      next attachment unless attachment

      file = direct[attachment[:id]]
      file&.file&.attached? ? attachment.merge(data_url: file.download_url) : attachment
    end
    data
  end

  private

  def execute_after_create_commit_callbacks
    super
    Cases::CustomerReplyJob.perform_later(id) if incoming? && !private? && account.feature_enabled?('cases')
  end
end
