# Aplica e desfaz uma proposta da Evolução da IA na base ou no prompt da
# persona (Supabase do botlayer, pelo Integrations::Botlayer::Client):
#   - knowledge_add: seção `### título` no fim do documento escolhido ou do
#     "Aprendizados da IA" da conta, criado na primeira vez e ligado à persona;
#   - knowledge_update: troca o trecho copiado da base (`replace_text`); se ele
#     não está mais lá, recusa (422) para ajustar à mão;
#   - prompt_rule: linha na seção `## Aprendizados` do fim do prompt.
# O antes e o depois ficam em `applied_change`; desfazer só volta se o texto
# ainda é o que a aplicação gravou, senão recusa em vez de apagar edição alheia.
class AiEvolution::Applier
  LEARNED_DOC_SLUG = 'aprendizados-da-ia'.freeze
  LEARNED_DOC_TITLE = 'Aprendizados da IA'.freeze
  LEARNED_DOC_PRIORITY = 900
  PROMPT_HEADING = '## Aprendizados'.freeze

  def initialize(suggestion, user)
    @suggestion = suggestion
    @user = user
  end

  # Edição antes de aplicar: título e texto que a equipe ajustou.
  def apply!(title: nil, content: nil)
    refuse!('only pending suggestions can be applied') unless @suggestion.pending?
    edit!(title, content)
    change = @suggestion.prompt_rule? ? apply_to_prompt! : apply_to_knowledge!
    @suggestion.update!(status: :applied, applied_at: Time.current, applied_by: @user, applied_change: change.stringify_keys)
    @suggestion
  end

  def undo!
    refuse!('only applied suggestions can be undone') unless @suggestion.applied?
    change = @suggestion.applied_change
    current = change['target'] == 'persona' ? persona_prompt : doc(change['id'])['content'].to_s
    refuse!('the text changed since it was applied; undo it by hand') unless current == change['after']

    write!(change['target'], change['id'], change['before'])
    @suggestion.update!(status: :pending, applied_at: nil, applied_by: nil, applied_change: nil)
    @suggestion
  end

  private

  def edit!(title, content)
    changes = { title: title.presence, content: content.presence }.compact
    return if changes.empty?

    @suggestion.assign_attributes(changes)
    @suggestion.edited = true if @suggestion.changed?
    @suggestion.save!
  end

  def apply_to_knowledge!
    target = @suggestion.target_doc_id ? doc(@suggestion.target_doc_id) : learned_doc
    before = target['content'].to_s
    after = @suggestion.knowledge_update? ? replace(before) : "#{before.rstrip}\n\n### #{@suggestion.title}\n#{@suggestion.content}".lstrip
    write!('doc', target['id'], after)
    { target: 'doc', id: target['id'], title: target['title'], before: before, after: after }
  end

  def replace(content)
    refuse!('the text to replace is no longer in the knowledge base') unless content.include?(@suggestion.replace_text)

    content.sub(@suggestion.replace_text) { @suggestion.content }
  end

  def apply_to_prompt!
    before = persona_prompt
    heading = before.include?(PROMPT_HEADING) ? '' : "\n\n#{PROMPT_HEADING}"
    after = "#{before.rstrip}#{heading}\n- #{@suggestion.content.squish}"
    write!('persona', @suggestion.persona_id, after)
    { target: 'persona', id: @suggestion.persona_id, before: before, after: after }
  end

  def write!(target, id, content)
    if target == 'persona'
      botlayer.update_persona(account_id, id, { system_prompt: content })
    else
      botlayer.update_knowledge_doc(account_id, id, { content: content })
    end
  end

  def doc(id)
    botlayer.knowledge_docs(account_id).find { |entry| entry['id'] == id } || refuse!('the knowledge document no longer exists')
  end

  # O documento dos aprendizados, ligado à persona da proposta.
  def learned_doc
    existing = botlayer.knowledge_docs(account_id).find { |entry| entry['slug'] == LEARNED_DOC_SLUG }
    entry = existing || botlayer.create_knowledge_doc(account_id, { slug: LEARNED_DOC_SLUG, title: LEARNED_DOC_TITLE, content: '',
                                                                    priority: LEARNED_DOC_PRIORITY, is_global: false, is_active: true })
    linked = Array(entry['bot_persona_knowledge']).pluck('persona_id')
    botlayer.set_doc_personas(account_id, entry['id'], linked | [@suggestion.persona_id]) unless linked.include?(@suggestion.persona_id)
    entry
  end

  def persona_prompt
    persona = botlayer.personas(account_id).find { |entry| entry['id'] == @suggestion.persona_id } || refuse!('the persona no longer exists')
    persona['system_prompt'].to_s
  end

  def refuse!(message)
    @suggestion.errors.add(:base, message)
    raise ActiveRecord::RecordInvalid, @suggestion
  end

  def account_id
    @suggestion.account_id
  end

  def botlayer
    @botlayer ||= Integrations::Botlayer::Client.new
  end
end
