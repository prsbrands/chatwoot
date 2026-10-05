# O que acontece com um documento depois de salvo: gerar o PDF (cada geração
# fica arquivada), enviar, aceitar ou recusar o orçamento, gerar a fatura,
# registrar pagamentos e anular. Fatura paga por inteiro marca o negócio como
# ganho, com o valor da fatura.
class Commerce::DocumentFlow
  def initialize(document, user: nil)
    @document = document
    @user = user
  end

  def archive_pdf!
    pdf = Commerce::DocumentPdf.new(@document).to_pdf
    @document.pdfs.attach(io: StringIO.new(pdf), filename: "#{@document.number}.pdf", content_type: 'application/pdf')
    @document.latest_pdf
  end

  def public_url
    "#{ENV.fetch('FRONTEND_URL')}/d/#{@document.public_token}"
  end

  def mark_sent!
    @document.update!(status: :sent, sent_at: Time.current) if @document.draft?
  end

  def accept!
    raise_unless(@document.quote? && @document.editable?)
    @document.update!(status: :accepted, accepted_at: Time.current)
  end

  def decline!
    raise_unless(@document.quote? && @document.editable?)
    @document.update!(status: :declined, declined_at: Time.current)
  end

  # Reabrir para edição: volta a rascunho (desfaz aceito, recusado ou anulado).
  # Fatura com pagamento não reabre; os PDFs gerados continuam no arquivo.
  def reopen!
    raise_unless(!@document.editable? && @document.payments.none? && !@document.paid? && !@document.partially_paid?)
    @document.update!(status: :draft, accepted_at: nil, declined_at: nil, voided_at: nil)
  end

  def archive!
    @document.update!(archived_at: Time.current)
  end

  def unarchive!
    @document.update!(archived_at: nil)
  end

  def void!
    raise_unless(!@document.void? && @document.payments.none?)
    @document.update!(status: :void, voided_at: Time.current)
  end

  # A fatura nasce do orçamento com as mesmas linhas e o mesmo cliente.
  def to_invoice!
    raise_unless(@document.quote? && !@document.void? && !@document.declined?)
    invoice = @document.account.commerce_documents.new(
      @document.slice(:language, :currency, :tax_mode, :contact_id, :deal_id, :appointment_id, :conversation_id,
                      :customer, :company, :notes, :terms, :footer)
               .merge(kind: :invoice, issue_date: Date.current, source_document: @document, created_by: @user)
    )
    @document.items.each { |line| invoice.items.build(line.slice(*Commerce::DocumentEditor::LINE, :position)) }
    invoice.recalculate!
    invoice.save!
    @document.update!(status: :accepted, accepted_at: Time.current) if @document.editable?
    invoice
  end

  def add_payment!(attrs)
    raise_unless(@document.invoice? && !@document.void? && !@document.draft?)
    Commerce::Document.transaction do
      @document.payments.create!(attrs.merge(account: @document.account, created_by: @user))
      settle!
    end
  end

  def remove_payment!(payment)
    Commerce::Document.transaction do
      payment.destroy!
      @document.payments.reset
      settle!
    end
  end

  private

  def settle!
    paid = @document.payments.sum(:amount)
    status = if paid.positive? && paid >= @document.total
               :paid
             elsif paid.positive?
               :partially_paid
             else
               :sent
             end
    @document.update!(amount_paid: paid, status: status, paid_at: status == :paid ? (@document.paid_at || Time.current) : nil)
    win_deal if @document.paid?
  end

  def win_deal
    deal = @document.deal || (@document.contact && @document.account.sales_deals.open.find_by(contact: @document.contact))
    return unless deal&.open?

    won = deal.pipeline.stages.find_by(kind: :won)
    deal.update!(value_cents: (@document.total * 100).to_i, currency: @document.currency)
    deal.move_to!(won, actor: @user || 'system', reason: "#{@document.number} paid") if won
  end

  def raise_unless(allowed)
    return if allowed

    @document.errors.add(:base, "#{@document.number} is #{@document.status}: action not allowed")
    raise ActiveRecord::RecordInvalid, @document
  end
end
