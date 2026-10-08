# Associações do CortexGen no contato, fora do model do upstream. Sem elas,
# excluir um contato deixava o negócio dele órfão e o Kanban quebrava ao
# renderizar o contato que não existe mais.
module CortexgenContact
  extend ActiveSupport::Concern

  included do
    has_many :sales_deals, class_name: 'Sales::Deal', dependent: :destroy_async
    has_many :sales_tasks, class_name: 'Sales::Task', dependent: :delete_all
    has_many :agenda_appointments, class_name: 'Agenda::Appointment', dependent: :nullify
    has_one :ai_memory_summary, class_name: 'AiMemory::Summary', dependent: :delete
    has_many :ai_memory_facts, class_name: 'AiMemory::Fact', dependent: :delete_all
  end
end
