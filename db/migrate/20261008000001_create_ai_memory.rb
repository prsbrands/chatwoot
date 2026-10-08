# Memória da IA por contato (vale em todos os canais): um resumo do cliente e
# fatos curtos. O workflow "CortexGen Memória" do n8n atualiza os dois quando a
# conversa fica parada; o MontaPrompt lê antes de responder. Fato escrito ou
# fixado por uma pessoa a IA não mexe.
class CreateAiMemory < ActiveRecord::Migration[7.1]
  def change
    create_summaries
    create_facts
  end

  private

  def create_summaries
    create_table :ai_memory_summaries do |t|
      t.references :account, null: false, index: false
      t.references :contact, null: false, index: { unique: true }
      t.text :body, null: false, default: ''
      # Maior id de mensagem já lido pela IA (ids são globais e crescentes):
      # a próxima rodada só manda as mensagens depois dele.
      t.bigint :last_message_id, null: false, default: 0
      t.datetime :refreshed_at
      # Reservada para uma rodada; falha do LLM tenta de novo depois de 1 h.
      t.datetime :claimed_at
      t.timestamps
    end
    add_index :ai_memory_summaries, [:account_id, :refreshed_at]
  end

  def create_facts
    create_table :ai_memory_facts do |t|
      t.references :account, null: false, index: false
      t.references :contact, null: false, index: false
      t.string :body, null: false
      t.integer :source, null: false, default: 0
      t.boolean :pinned, null: false, default: false
      t.references :conversation, index: false
      t.references :created_by, index: false
      t.timestamps
    end
    add_index :ai_memory_facts, [:contact_id, :pinned, :created_at]
  end
end
