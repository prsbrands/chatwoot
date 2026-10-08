# Ao juntar dois contatos, o que o CortexGen guarda por contato passa para o que
# fica. Sem isso, o negócio e as tarefas do contato absorvido eram apagados com
# ele, e compromissos, orçamentos, faturas e assinaturas ficavam apontando para
# um contato que não existe mais. A memória da IA também se junta: fatos dos
# dois e os resumos lado a lado, com a leitura voltando ao ponto mais antigo
# para a IA reler o que faltou de um deles.
module CortexgenContactMerge
  MOVED = %w[Sales::Deal Sales::Task Agenda::Appointment Commerce::Document Commerce::Subscription AiMemory::Fact].freeze

  private

  def merge_contact_notes
    super
    # rubocop:disable Rails/SkipsModelValidations
    MOVED.each { |model| model.constantize.where(contact_id: @mergee_contact.id).update_all(contact_id: @base_contact.id) }
    # rubocop:enable Rails/SkipsModelValidations
    merge_ai_memory_summary
  end

  def merge_ai_memory_summary
    mergee = AiMemory::Summary.find_by(contact_id: @mergee_contact.id)
    return unless mergee

    base = AiMemory::Summary.find_by(contact_id: @base_contact.id)
    return mergee.update!(contact_id: @base_contact.id) unless base

    base.update!(body: [base.body, mergee.body].compact_blank.join("\n\n"),
                 last_message_id: [base.last_message_id, mergee.last_message_id].min)
    mergee.destroy!
  end
end
