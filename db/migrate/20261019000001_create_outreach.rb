# Campanhas por QR (flag `outreach`): disparo para uma lista pelo WhatsApp por
# QR (OpenWA), com ritmo e vetos que protegem o número. Desenho em
# docs/cortexgen/campanhas.md.
class CreateOutreach < ActiveRecord::Migration[7.1]
  def change
    create_campaigns
    create_recipients
    create_suppressions
  end

  private

  def create_campaigns
    create_table :outreach_campaigns do |t|
      t.references :account, null: false, index: false
      t.references :inbox, null: false, index: false
      t.references :created_by, index: false
      t.string :name, null: false
      t.integer :status, null: false, default: 0
      message_columns(t)
      state_columns(t)
      t.timestamps
    end
    add_index :outreach_campaigns, [:account_id, :status]
    add_index :outreach_campaigns, [:inbox_id, :status]
  end

  def message_columns(table)
    # Até 3 textos; o envio alterna entre eles.
    table.jsonb :variants, null: false, default: []
    table.boolean :cold, null: false, default: false
    table.text :opt_out_footer
    table.jsonb :pacing, null: false, default: {}
    table.jsonb :audience, null: false, default: {}
    table.integer :attribution_hours, null: false, default: 72
  end

  def state_columns(table)
    table.datetime :started_at
    table.datetime :paused_at
    table.string :paused_reason
    table.datetime :completed_at
    # Quando o próximo envio pode sair (intervalo e pausa do lote) e quando a
    # cadeia de envio acorda de novo.
    table.datetime :next_send_at
    table.datetime :wake_at
    table.integer :batch_sent, null: false, default: 0
  end

  def create_recipients
    create_table :outreach_recipients do |t|
      t.references :account, null: false, index: false
      t.references :campaign, null: false, index: false
      t.string :phone, null: false
      t.string :name
      # As colunas da lista importada, por apelido, para as variáveis da mensagem.
      t.jsonb :variables, null: false, default: {}
      # Preenchidos quando o cliente responde.
      t.bigint :contact_id
      t.bigint :conversation_id
      t.integer :variant
      t.integer :status, null: false, default: 0
      t.string :excluded_reason
      t.text :error
      t.datetime :sent_at
      t.datetime :replied_at
      t.timestamps
    end
    add_index :outreach_recipients, [:campaign_id, :status, :id]
    add_index :outreach_recipients, [:campaign_id, :phone]
    add_index :outreach_recipients, [:account_id, :phone, :sent_at]
  end

  def create_suppressions
    create_table :outreach_suppressions do |t|
      t.references :account, null: false, index: false
      t.string :phone, null: false
      t.string :reason
      t.references :created_by, index: false
      t.timestamps
    end
    add_index :outreach_suppressions, [:account_id, :phone], unique: true
  end
end
