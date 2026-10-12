# A aba Progress da Evolução da IA: por semana, nas caixas com bot, as
# conversas em que o cliente escreveu, quantas a IA passou para a equipe
# (nota da Passagem), quantas respostas o Jev reteve, os casos abertos pela IA
# e as propostas aplicadas. Não atribui causa: mostra a tendência ao lado das
# mudanças.
class AiEvolution::Progress
  WEEKS = 12

  def initialize(account)
    @account = account
    @since = (WEEKS - 1).weeks.ago.beginning_of_week
  end

  def weeks
    series = { conversations: conversations, handoffs: notes('^(Handoff|Passagem|Traspaso) · '),
               held: notes('^(Handoff|Passagem|Traspaso) · .*(Held draft|Rascunho retido|Borrador retenido)'), ai_cases: ai_cases, applied: applied }
    week_starts.map do |start|
      { week: start.to_date.iso8601 }.merge(series.transform_values { |counts| counts[start.to_date] || 0 })
    end
  end

  private

  def week_starts
    (0...WEEKS).map { |offset| @since + offset.weeks }
  end

  def bot_inbox_ids
    @bot_inbox_ids ||= AgentBotInbox.where(account_id: @account.id).pluck(:inbox_id)
  end

  def bot_messages
    Message.reorder(nil).where(account_id: @account.id, inbox_id: bot_inbox_ids, created_at: @since..)
  end

  def by_week(scope, column)
    scope.group(Arel.sql("date_trunc('week', #{column})")).count.transform_keys(&:to_date)
  end

  def conversations
    bot_messages.where(message_type: :incoming, private: false)
                .group(Arel.sql("date_trunc('week', messages.created_at)")).distinct.count(:conversation_id).transform_keys(&:to_date)
  end

  def notes(pattern)
    by_week(bot_messages.where(private: true).where('messages.content ~ ?', pattern), 'messages.created_at')
  end

  def ai_cases
    by_week(@account.cases.where(source: :ai, created_at: @since..), 'cases_cases.created_at')
  end

  def applied
    by_week(@account.ai_evolution_suggestions.where(applied_at: @since..), 'ai_evolution_suggestions.applied_at')
  end
end
