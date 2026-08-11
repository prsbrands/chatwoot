# Pedido de ligação de demo feito por um formulário público (sem sessão do
# painel). Guarda o consentimento e serve de fonte para o limite por
# telefone em `Voice::PublicCallRequestService` — ver ali antes de mexer aqui.
class VoiceCallRequest < ApplicationRecord
  STATUSES = %w[pending dispatched rejected failed].freeze

  belongs_to :account
  belongs_to :twilio_voice_route, optional: true

  validates :name, :email, :phone_number, :ip_address, presence: true
  validates :status, inclusion: { in: STATUSES }
end
