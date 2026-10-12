# Associacoes do CortexGen na conta (Twilio proprio, funil, agenda, comercial, memoria da IA, casos e evolucao da IA), fora do
# model do upstream: o Account fica como o do Chatwoot e o merge sem conflito.
module CortexgenAccount
  extend ActiveSupport::Concern

  included do
    has_one :twilio_credential, dependent: :destroy_async
    has_many :twilio_voice_routes, dependent: :destroy_async
    has_many :twilio_voice_calls, dependent: :destroy_async
    has_many :sales_pipelines, class_name: 'Sales::Pipeline', dependent: :destroy_async
    has_many :sales_deals, class_name: 'Sales::Deal', dependent: :destroy_async
    has_many :sales_tasks, class_name: 'Sales::Task', dependent: :delete_all
    has_many :agenda_appointments, class_name: 'Agenda::Appointment', dependent: :delete_all
    has_many :agenda_google_connections, class_name: 'Agenda::GoogleConnection', dependent: :delete_all
    has_many :agenda_event_types, class_name: 'Agenda::EventType', dependent: :delete_all
    has_many :agenda_availabilities, class_name: 'Agenda::Availability', dependent: :delete_all
    has_many :commerce_categories, class_name: 'Commerce::Category', dependent: :delete_all
    has_many :commerce_items, class_name: 'Commerce::Item', dependent: :destroy_async
    has_one :commerce_profile, class_name: 'Commerce::Profile', dependent: :destroy
    has_many :commerce_payment_methods, class_name: 'Commerce::PaymentMethod', dependent: :delete_all
    has_many :commerce_documents, class_name: 'Commerce::Document', dependent: :destroy_async
    has_many :commerce_payment_providers, class_name: 'Commerce::PaymentProvider', dependent: :delete_all
    has_many :commerce_checkouts, class_name: 'Commerce::Checkout', dependent: :delete_all
    has_many :commerce_subscriptions, class_name: 'Commerce::Subscription', dependent: :delete_all
    has_many :ai_memory_summaries, class_name: 'AiMemory::Summary', dependent: :delete_all
    has_many :ai_memory_facts, class_name: 'AiMemory::Fact', dependent: :delete_all
    has_many :cases_types, class_name: 'Cases::Type', dependent: :delete_all
    has_many :cases, class_name: 'Cases::Case', dependent: :delete_all
    has_many :cases_conversations, class_name: 'Cases::CaseConversation', dependent: :delete_all
    has_many :cases_events, class_name: 'Cases::Event', dependent: :delete_all
    has_many :ai_evolution_scans, class_name: 'AiEvolution::Scan', dependent: :delete_all
    has_many :ai_evolution_suggestions, class_name: 'AiEvolution::Suggestion', dependent: :delete_all

    store_accessor :settings, :cases_prefix
  end
end
