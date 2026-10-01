# Bloco 3c: risco e score do negocio, numa tabela a parte. No DeskComm, score
# e risco dentro da tabela de negocios faziam o quadro piscar e o salvar dar
# conflito (o updated_at mudava a cada varredura). Aqui o negocio so muda
# quando alguem mexe nele.
class CreateSalesDealInsights < ActiveRecord::Migration[7.1]
  def change
    create_table :sales_deal_insights do |t|
      t.references :account, null: false, index: true
      t.references :deal, null: false, index: { unique: true }
      # Ultima interacao real (mensagem do cliente ou resposta publica).
      t.datetime :last_activity_at
      # on_track | at_risk | critical
      t.integer :risk, null: false, default: 0
      t.datetime :risk_since
      # O que o Jev viu na conversa: chave => probabilidade (compromissos,
      # objecoes, qualificacao), e a mensagem do cliente avaliada.
      t.jsonb :facts, null: false, default: {}
      t.bigint :facts_message_id
      t.datetime :facts_at
      t.integer :score
      t.string :score_band
      t.jsonb :score_factors, null: false, default: []
      t.timestamps
    end
  end
end
