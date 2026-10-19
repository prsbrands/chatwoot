# Uma campanha por QR: a mensagem (até 3 variações), o número (inbox de
# WhatsApp por QR), o ritmo e a lista. Quem manda é o Outreach::SendNextJob, uma
# mensagem por vez; o estado só muda por `transition_to!`. Desenho em
# docs/cortexgen/campanhas.md.
class Outreach::Campaign < ApplicationRecord
  self.table_name = 'outreach_campaigns'

  MAX_VARIANTS = 3
  MAX_VARIANT_LENGTH = 1000
  # Voltar a `draft` é o caminho de editar a lista e o texto; só vale antes de iniciar.
  TRANSITIONS = {
    'draft' => %w[ready cancelled],
    'ready' => %w[draft running cancelled],
    'running' => %w[paused completed cancelled],
    'paused' => %w[running cancelled],
    'completed' => [],
    'cancelled' => []
  }.freeze

  LIVE_STATUSES = %w[ready running paused].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :recipients, class_name: 'Outreach::Recipient', dependent: :delete_all

  enum :status, { draft: 0, ready: 1, running: 2, paused: 3, completed: 4, cancelled: 5 }, validate: true

  validates :name, presence: true, length: { maximum: 120 }
  validates :attribution_hours, numericality: { only_integer: true, in: 1..720 }
  validate :variants_valid
  validate :inbox_is_qr
  validate :pacing_valid

  # Inbox de WhatsApp por QR: API ligada ao adaptador do OpenWA.
  def self.qr_inbox?(inbox)
    inbox.channel_type == 'Channel::Api' && inbox.channel.webhook_url.to_s.include?('/chatwoot-adapter/')
  end

  def pace
    Outreach::Pacing.new(pacing)
  end

  def editable?
    draft?
  end

  def transition_to!(new_status, attributes = {})
    unless TRANSITIONS.fetch(status).include?(new_status.to_s)
      errors.add(:status, "cannot go from #{status} to #{new_status}")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(attributes.merge(status: new_status))
  end

  # Inicia ou retoma: confere o que a campanha precisa para mandar e acorda a
  # cadeia de envio na hora.
  def start!
    ensure_startable!
    transition_to!(:running, started_at: started_at || Time.current, paused_at: nil, paused_reason: nil, next_send_at: nil)
    schedule_wake!(Time.current)
  end

  # Acorda a cadeia de envio no horário dado. Só o último `wake_at` vale: um
  # acordar atrasado ou repetido vê que não é o atual e sai.
  def schedule_wake!(time)
    update!(wake_at: time)
    Outreach::SendNextJob.set(wait_until: time).perform_later(self, time.to_f)
  end

  private

  def ensure_startable!
    errors.add(:inbox, 'needs a time zone other than UTC') if inbox.timezone == 'UTC'
    errors.add(:inbox, 'WhatsApp session is disconnected') if inbox.channel.reauthorization_required?
    errors.add(:base, 'no one is waiting to receive') unless recipients.pending.exists?
    raise ActiveRecord::RecordInvalid, self if errors.any?
  end

  def variants_valid
    texts = Array(variants)
    return errors.add(:variants, 'must have between 1 and 3 texts') unless texts.size.between?(1, MAX_VARIANTS)

    valid = texts.all? { |text| text.is_a?(String) && text.strip.present? && text.size <= MAX_VARIANT_LENGTH }
    errors.add(:variants, 'must be texts up to 1000 characters') unless valid
  end

  def inbox_is_qr
    return if inbox.blank?

    errors.add(:inbox, 'must be a WhatsApp QR inbox of the account') unless inbox.account_id == account_id && self.class.qr_inbox?(inbox)
  end

  def pacing_valid
    Outreach::Pacing.errors(pacing).each { |key| errors.add(:pacing, key) }
  end
end
