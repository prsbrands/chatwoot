# Orçamento ou fatura. O número (COT-2026-0001, FAT-2026-0001) é por tipo e por
# ano, com o prefixo da empresa. Os dados da empresa e do cliente são copiados
# quando o documento é salvo enquanto pode ser editado: depois de aceito, pago
# ou anulado ele não muda mais. Todo PDF gerado fica arquivado em `pdfs`.
class Commerce::Document < ApplicationRecord
  LANGUAGES = %w[es pt en].freeze
  CUSTOMER_FIELDS = %w[name tax_id_label tax_id address email phone].freeze

  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :deal, class_name: 'Sales::Deal', optional: true
  belongs_to :appointment, class_name: 'Agenda::Appointment', optional: true
  belongs_to :conversation, optional: true
  belongs_to :source_document, class_name: 'Commerce::Document', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :items, -> { order(:position, :id) }, class_name: 'Commerce::DocumentItem', dependent: :delete_all, inverse_of: :document
  has_many :payments, -> { order(:paid_on, :id) }, class_name: 'Commerce::DocumentPayment', dependent: :delete_all, inverse_of: :document
  has_many_attached :pdfs

  enum :kind, { quote: 0, invoice: 1 }, validate: true
  enum :status, { draft: 0, sent: 1, accepted: 2, declined: 3, partially_paid: 4, paid: 5, void: 6 }, validate: true
  # exclusive: o imposto soma por fora do preço; inclusive: o preço já tem o
  # imposto; exempt: sem imposto, as alíquotas das linhas são ignoradas.
  enum :tax_mode, { exclusive: 0, inclusive: 1, exempt: 2 }, validate: true

  validates :language, inclusion: { in: LANGUAGES }
  validates :currency, inclusion: { in: Commerce::CURRENCIES }
  validates :issue_date, presence: true
  validate :status_fits_kind

  before_validation :assign_number, on: :create
  before_validation -> { self.public_token ||= SecureRandom.urlsafe_base64(24) }, on: :create

  # Aceito, recusado, pago ou anulado: o documento é histórico.
  def editable?
    draft? || sent?
  end

  def balance
    total - amount_paid
  end

  # Situação para a tela: enviado depois da validade (orçamento) ou do
  # vencimento (fatura) aparece como vencido.
  def display_status
    return status unless due_date&.past? && awaiting_customer?

    quote? ? 'expired' : 'overdue'
  end

  def recalculate!
    Commerce::DocumentTotals.new(self).apply!
  end

  def latest_pdf
    pdfs.attachments.max_by(&:created_at)
  end

  private

  def awaiting_customer?
    sent? || (invoice? && partially_paid?)
  end

  def assign_number
    return if number.present?

    self.year = issue_date.year
    self.sequence = account.commerce_documents.where(kind: kind, year: year).maximum(:sequence).to_i + 1
    prefix = Commerce::Profile.for(account).public_send(quote? ? :quote_prefix : :invoice_prefix)
    self.number = "#{prefix}-#{year}-#{sequence.to_s.rjust(4, '0')}"
  end

  def status_fits_kind
    allowed = quote? ? %w[draft sent accepted declined void] : %w[draft sent partially_paid paid void]
    errors.add(:status, :inclusion) unless allowed.include?(status)
  end
end
