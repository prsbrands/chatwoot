# Textos que saem DENTRO do documento (PDF, página pública, e-mail ao cliente).
# Cada documento escolhe o idioma — uma conta atende clientes em vários países —,
# então eles ficam aqui nos três idiomas, e não no i18n da interface.
module Commerce::DocumentLabels
  LABELS = {
    'es' => {
      quote: 'Cotización', invoice: 'Factura', number: 'N.º', issue_date: 'Fecha', valid_until: 'Válida hasta',
      due_date: 'Vencimiento', bill_to: 'Cliente', description: 'Descripción', quantity: 'Cant.', unit_price: 'Precio unit.',
      discount: 'Desc.', tax: 'Impuesto', amount: 'Importe', subtotal: 'Subtotal', discount_total: 'Descuento',
      tax_total: 'Impuestos', total: 'Total', paid: 'Pagado', balance: 'Saldo', tax_included: 'Impuestos incluidos',
      tax_exempt: 'Exento de impuestos', payment_methods: 'Formas de pago', terms: 'Condiciones', notes: 'Observaciones',
      on_quote: 'A cotizar', accept: 'Aceptar cotización', decline: 'Rechazar', download: 'Descargar PDF',
      accepted: 'Cotización aceptada. ¡Gracias!', declined: 'Cotización rechazada.', status_paid: 'Pagada',
      status_void: 'Anulada', page: 'Página', email_greeting: 'Hola %<name>s,', email_body: 'Adjuntamos %<document>s %<number>s.',
      email_link: 'También puede verla en línea:', email_thanks: 'Gracias.', message: '%<document>s %<number>s: %<url>s'
    },
    'pt' => {
      quote: 'Orçamento', invoice: 'Fatura', number: 'N.º', issue_date: 'Data', valid_until: 'Válido até',
      due_date: 'Vencimento', bill_to: 'Cliente', description: 'Descrição', quantity: 'Qtd.', unit_price: 'Preço unit.',
      discount: 'Desc.', tax: 'Imposto', amount: 'Valor', subtotal: 'Subtotal', discount_total: 'Desconto',
      tax_total: 'Impostos', total: 'Total', paid: 'Pago', balance: 'Saldo', tax_included: 'Impostos inclusos',
      tax_exempt: 'Isento de impostos', payment_methods: 'Formas de pagamento', terms: 'Condições', notes: 'Observações',
      on_quote: 'Sob orçamento', accept: 'Aceitar orçamento', decline: 'Recusar', download: 'Baixar PDF',
      accepted: 'Orçamento aceito. Obrigado!', declined: 'Orçamento recusado.', status_paid: 'Paga',
      status_void: 'Anulada', page: 'Página', email_greeting: 'Olá %<name>s,', email_body: 'Segue %<document>s %<number>s em anexo.',
      email_link: 'Você também pode ver online:', email_thanks: 'Obrigado.', message: '%<document>s %<number>s: %<url>s'
    },
    'en' => {
      quote: 'Quote', invoice: 'Invoice', number: 'No.', issue_date: 'Date', valid_until: 'Valid until',
      due_date: 'Due date', bill_to: 'Bill to', description: 'Description', quantity: 'Qty', unit_price: 'Unit price',
      discount: 'Disc.', tax: 'Tax', amount: 'Amount', subtotal: 'Subtotal', discount_total: 'Discount',
      tax_total: 'Tax', total: 'Total', paid: 'Paid', balance: 'Balance due', tax_included: 'Tax included',
      tax_exempt: 'Tax exempt', payment_methods: 'Payment methods', terms: 'Terms', notes: 'Notes',
      on_quote: 'Price on request', accept: 'Accept quote', decline: 'Decline', download: 'Download PDF',
      accepted: 'Quote accepted. Thank you!', declined: 'Quote declined.', status_paid: 'Paid',
      status_void: 'Void', page: 'Page', email_greeting: 'Hello %<name>s,', email_body: 'Please find attached %<document>s %<number>s.',
      email_link: 'You can also view it online:', email_thanks: 'Thank you.', message: '%<document>s %<number>s: %<url>s'
    }
  }.freeze

  UNITS = {
    'es' => { 'unit' => 'un', 'hour' => 'h', 'day' => 'día', 'week' => 'semana', 'month' => 'mes', 'm' => 'm', 'm2' => 'm²',
              'm3' => 'm³', 'kg' => 'kg', 'liter' => 'L', 'package' => 'paquete', 'project' => 'proyecto', 'service' => 'servicio' },
    'pt' => { 'unit' => 'un', 'hour' => 'h', 'day' => 'dia', 'week' => 'semana', 'month' => 'mês', 'm' => 'm', 'm2' => 'm²',
              'm3' => 'm³', 'kg' => 'kg', 'liter' => 'L', 'package' => 'pacote', 'project' => 'projeto', 'service' => 'serviço' },
    'en' => { 'unit' => 'unit', 'hour' => 'h', 'day' => 'day', 'week' => 'week', 'month' => 'month', 'm' => 'm', 'm2' => 'm²',
              'm3' => 'm³', 'kg' => 'kg', 'liter' => 'L', 'package' => 'package', 'project' => 'project', 'service' => 'service' }
  }.freeze

  def self.for(language)
    LABELS.fetch(language)
  end

  def self.unit(language, unit)
    UNITS.fetch(language).fetch(unit, unit)
  end

  def self.money(amount, currency, language)
    locale = { 'es' => :es, 'pt' => :'pt-BR', 'en' => :en }.fetch(language)
    symbol = { 'USD' => '$', 'BRL' => 'R$', 'EUR' => '€' }.fetch(currency)
    separator, delimiter = language == 'en' ? ['.', ','] : [',', '.']
    formatted = ActiveSupport::NumberHelper.number_to_currency(amount, unit: '', precision: 2, separator: separator,
                                                                       delimiter: delimiter, locale: locale).strip
    "#{symbol} #{formatted}"
  end

  def self.date(value, language)
    return '' unless value

    language == 'en' ? value.strftime('%m/%d/%Y') : value.strftime('%d/%m/%Y')
  end
end
