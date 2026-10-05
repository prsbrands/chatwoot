# Totais do documento a partir das linhas e do modo de imposto. Cada linha:
#   bruto = quantidade × preço; desconto = bruto × desconto%; líquido = bruto − desconto
#   exclusive: imposto = líquido × alíquota; total da linha = líquido + imposto
#   inclusive: o líquido já tem o imposto; imposto = líquido − líquido / (1 + alíquota)
#   exempt: sem imposto
# Documento: subtotal = soma dos brutos; total = soma dos totais das linhas.
# Linha sem preço (item "sob orçamento" ainda não cotado) entra com zero.
class Commerce::DocumentTotals
  def initialize(document)
    @document = document
  end

  def apply!
    @document.items.each { |line| price(line) }
    @document.assign_attributes(
      subtotal: sum(:line_subtotal), discount_total: sum(:line_discount),
      tax_total: sum(:line_tax), total: sum(:line_total)
    )
    @document
  end

  private

  def price(line)
    gross = round(line.quantity.to_d * line.unit_price.to_d)
    discount = round(gross * line.discount_percent.to_d / 100)
    net = gross - discount
    tax = tax_for(net, line.tax_rate.to_d)
    line.assign_attributes(line_subtotal: gross, line_discount: discount, line_tax: tax,
                           line_total: @document.exclusive? ? net + tax : net)
  end

  def tax_for(net, rate)
    return 0.to_d if @document.exempt? || rate.zero?
    return round(net * rate / 100) if @document.exclusive?

    round(net - (net / (1 + (rate / 100))))
  end

  def sum(column)
    @document.items.sum { |line| line.public_send(column) }
  end

  def round(value)
    value.round(2, BigDecimal::ROUND_HALF_UP)
  end
end
