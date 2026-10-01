# Associacoes do CortexGen na conta (Twilio proprio e funil de vendas), fora do
# model do upstream: o Account fica como o do Chatwoot e o merge sem conflito.
module CortexgenAccount
  extend ActiveSupport::Concern

  included do
    has_one :twilio_credential, dependent: :destroy_async
    has_many :twilio_voice_routes, dependent: :destroy_async
    has_many :twilio_voice_calls, dependent: :destroy_async
    has_many :sales_pipelines, class_name: 'Sales::Pipeline', dependent: :destroy_async
    has_many :sales_deals, class_name: 'Sales::Deal', dependent: :destroy_async
  end
end
