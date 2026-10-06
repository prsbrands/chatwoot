# PDF do orçamento, da fatura ou do recibo (Prawn), no idioma do documento. As fontes
# embutidas da Prawn só conhecem Windows-1252 (cobre espanhol, português, inglês
# e €): o que ficar fora disso vira "?" em vez de derrubar a geração.
# Layout: um método por bloco do papel; as métricas de tamanho não ajudam aqui.
# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/ClassLength
class Commerce::DocumentPdf
  include Prawn::View

  MUTED = '666666'.freeze
  LINE = 'DDDDDD'.freeze
  LOGO_BOX = [160, 70].freeze

  def initialize(document)
    @doc = document
    @l = Commerce::DocumentLabels.for(document.language)
  end

  def document
    @document ||= Prawn::Document.new(page_size: 'A4', margin: [40, 40, 50, 40], info: { Title: @doc.number })
  end

  def to_pdf
    # O aviso da Prawn é sobre a falta de UTF-8 nas fontes embutidas; o texto já
    # passa por t(), que troca o que não cabe em Windows-1252.
    Prawn::Fonts::AFM.hide_m17n_warning = true
    font('Helvetica', size: 9)
    header
    customer
    if @doc.receipt?
      receipt_summary
    else
      lines
      totals
      payment_methods
    end
    texts
    page_footer
    document.render
  end

  private

  def t(value)
    value.to_s.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?').encode('UTF-8')
  end

  def money(value)
    Commerce::DocumentLabels.money(value, @doc.currency, @doc.language)
  end

  def company
    @doc.company || {}
  end

  def header
    top = cursor
    logo
    bounding_box([bounds.width / 2, top], width: bounds.width / 2) do
      text t(company['trade_name'].presence || company['legal_name']), size: 13, style: :bold, align: :right
      company_lines.each { |line| text t(line), align: :right, color: MUTED }
    end
    move_down 18
    title = "#{@l[@doc.kind.to_sym]} #{@doc.number}"
    text t(title), size: 16, style: :bold
    stamp_status
    dates = ["#{@l[:issue_date]}: #{Commerce::DocumentLabels.date(@doc.issue_date, @doc.language)}"]
    dates << "#{@l[@doc.quote? ? :valid_until : :due_date]}: #{Commerce::DocumentLabels.date(@doc.due_date, @doc.language)}" if @doc.due_date
    text t(dates.join('     ')), color: MUTED
    move_down 14
  end

  def company_lines
    [
      company['legal_name'].presence && company['legal_name'] != company['trade_name'] ? company['legal_name'] : nil,
      company['tax_id'].present? ? "#{company['tax_id_label']} #{company['tax_id']}".strip : nil,
      company['address'], company['phone'], company['email'], company['website']
    ].compact_blank
  end

  def logo
    blob = company['logo_blob_id'] && ActiveStorage::Blob.find_by(id: company['logo_blob_id'])
    return unless blob

    blob.open do |file|
      png = ImageProcessing::Vips.source(file.path).convert('png').resize_to_limit(600, 300).call
      image png.path, fit: LOGO_BOX, at: [0, cursor]
    end
  rescue StandardError => e
    Rails.logger.warn("[COMMERCE] logo left out of #{@doc.number}: #{e.message}")
  end

  def stamp_status
    label = { 'paid' => :status_paid, 'void' => :status_void }[@doc.status]
    return unless label

    text t(@l[label].upcase), size: 12, style: :bold, color: @doc.paid? ? '1A7F37' : 'B42318'
  end

  def customer
    data = @doc.customer || {}
    rows = [data['name'], data['tax_id'].present? ? "#{data['tax_id_label']} #{data['tax_id']}".strip : nil,
            data['address'], data['email'], data['phone']].compact_blank
    return if rows.empty?

    text t(@l[@doc.receipt? ? :received_from : :bill_to]).upcase, size: 8, style: :bold, color: MUTED
    text t(rows.first), size: 11, style: :bold
    rows.drop(1).each { |row| text t(row) }
    move_down 14
  end

  def lines
    show_discount = @doc.items.any? { |line| line.discount_percent.to_d.positive? }
    show_tax = !@doc.exempt? && @doc.items.any? { |line| line.tax_rate.to_d.positive? }
    head = [@l[:description], @l[:quantity], @l[:unit_price]]
    head << @l[:discount] if show_discount
    head << @l[:tax] if show_tax
    head << @l[:amount]
    rows = @doc.items.map { |line| line_row(line, show_discount, show_tax) }
    style = { borders: [:bottom], border_color: LINE, padding: [6, 4] }
    table([head.map { |h| t(h) }] + rows, header: true, width: bounds.width, cell_style: style) do |tbl|
      tbl.row(0).font_style = :bold
      tbl.row(0).background_color = 'F3F3F3'
      tbl.columns(1..-1).align = :right
      tbl.column(0).width = tbl.width * 0.42
    end
    move_down 10
  end

  def line_row(line, show_discount, show_tax)
    priced = !line.unit_price.nil?
    description = line.description.present? ? "\n<color rgb='#{MUTED}'>#{escape(line.description)}</color>" : ''
    name = make_cell(content: "<b>#{escape(line.name)}</b>#{description}", inline_format: true)
    row = [name, t("#{format_quantity(line.quantity)} #{Commerce::DocumentLabels.unit(@doc.language, line.unit)}"),
           t(priced ? money(line.unit_price) : @l[:on_quote])]
    row << (line.discount_percent.to_d.positive? ? "#{format_quantity(line.discount_percent)}%" : '') if show_discount
    row << (line.tax_rate.to_d.positive? ? "#{format_quantity(line.tax_rate)}%" : '') if show_tax
    row << t(priced ? money(line.line_total) : @l[:on_quote])
  end

  # O recibo não tem linhas: a declaração do valor recebido e o quadro com a
  # posição da fatura depois deste pagamento.
  def receipt_summary
    data = @doc.details
    statement = format(@l[:receipt_statement], amount: money(@doc.total), document: "#{@l[:invoice]} #{data['invoice_number']}")
    text t(statement), size: 11
    move_down 10
    rows = [[@l[:payment_date], Commerce::DocumentLabels.date(data['paid_on'] && Date.parse(data['paid_on']), @doc.language)],
            [@l[:payment_method], data['method'].presence || '—'],
            [@l[:amount_received], money(@doc.total)],
            [@l[:invoice_total], money(data['invoice_total'])],
            [@l[:paid_to_date], money(data['paid_to_date'])],
            [@l[:balance], money(data['balance'])]]
    style = { borders: [:bottom], border_color: LINE, padding: [5, 4] }
    table(rows.map { |row| row.map { |cell| t(cell) } }, width: bounds.width * 0.6, cell_style: style) do |tbl|
      tbl.column(1).align = :right
      tbl.row(2).font_style = :bold
    end
    move_down 14
  end

  def escape(value)
    ERB::Util.html_escape(t(value))
  end

  def format_quantity(value)
    value.to_d.frac.zero? ? value.to_i.to_s : value.to_d.round(3).to_s('F')
  end

  def totals
    rows = [[@l[:subtotal], money(@doc.subtotal)]]
    rows << [@l[:discount_total], "- #{money(@doc.discount_total)}"] if @doc.discount_total.positive?
    rows << [@l[:tax_total], money(@doc.tax_total)] if @doc.exclusive? && @doc.tax_total.positive?
    rows << [@l[:total], money(@doc.total)]
    if @doc.invoice? && @doc.amount_paid.positive?
      rows << [@l[:paid], money(@doc.amount_paid)]
      rows << [@l[:balance], money(@doc.balance)]
    end
    total_row = rows.index { |label, _| label == @l[:total] }
    bounding_box([bounds.width * 0.55, cursor], width: bounds.width * 0.45) do
      table(rows.map { |row| row.map { |cell| t(cell) } }, width: bounds.width, cell_style: { borders: [], padding: [3, 4] }) do |tbl|
        tbl.column(1).align = :right
        tbl.row(total_row).font_style = :bold
        tbl.row(total_row).size = 11
      end
      tax_note
    end
    move_down 14
  end

  def tax_note
    note = if @doc.exempt?
             @l[:tax_exempt]
           elsif @doc.inclusive? && @doc.tax_total.positive?
             "#{@l[:tax_included]}: #{money(@doc.tax_total)}"
           end
    text t(note), size: 8, color: MUTED, align: :right if note
  end

  def payment_methods
    methods = @doc.payment_methods
    return if methods.empty? || @doc.paid? || @doc.void?

    section(@l[:payment_methods]) do
      methods.each do |method|
        text t(method.name), style: :bold
        text t(method.instructions), color: MUTED if method.instructions.present?
        move_down 4
      end
    end
  end

  def texts
    section(@l[:notes]) { text t(@doc.notes) } if @doc.notes.present?
    section(@l[:terms]) { text t(@doc.terms) } if @doc.terms.present?
  end

  def section(title)
    text t(title).upcase, size: 8, style: :bold, color: MUTED
    move_down 2
    yield
    move_down 10
  end

  def page_footer
    footer = t(@doc.footer)
    page_label = t(@l[:page])
    if footer.present?
      repeat(:all) do
        canvas { text_box footer, at: [40, 38], width: bounds.width - 80, height: 14, size: 8, color: MUTED, align: :center }
      end
    end
    number_pages("#{page_label} <page>/<total>", at: [bounds.right - 100, -20], width: 100, align: :right, size: 7, color: MUTED)
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/ClassLength
