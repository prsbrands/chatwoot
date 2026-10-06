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
      email_thanks: 'Gracias.',
      view_document: 'Ver %<document>s', regards: 'Saludos,', message: '%<document>s %<number>s: %<url>s',
      receipt: 'Recibo', received_from: 'Recibido de', amount_received: 'Monto recibido', payment_date: 'Fecha de pago',
      payment_method: 'Forma de pago', invoice_total: 'Total de la factura', paid_to_date: 'Pagado a la fecha',
      receipt_statement: 'Recibimos la suma de %<amount>s como pago de la %<document>s.', pay_online: 'Pagar en línea',
      amount_to_pay: 'Monto a pagar', pay_amount_hint: 'Puedes pagar el saldo completo o una parte (mínimo %<minimum>s).',
      pay_with: 'Pagar con %<method>s', pay_error: 'No pudimos iniciar el pago. Revisa el monto e inténtalo de nuevo.',
      payment_processing: 'Estamos confirmando tu pago. Esta página se actualizará sola.',
      payment_received: '¡Pago recibido, gracias! Te enviaremos el recibo.'
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
      email_thanks: 'Obrigado.',
      view_document: 'Ver %<document>s', regards: 'Atenciosamente,', message: '%<document>s %<number>s: %<url>s',
      receipt: 'Recibo', received_from: 'Recebido de', amount_received: 'Valor recebido', payment_date: 'Data do pagamento',
      payment_method: 'Forma de pagamento', invoice_total: 'Total da fatura', paid_to_date: 'Pago até agora',
      receipt_statement: 'Recebemos a quantia de %<amount>s como pagamento da %<document>s.', pay_online: 'Pagar online',
      amount_to_pay: 'Valor a pagar', pay_amount_hint: 'Você pode pagar o saldo inteiro ou uma parte (mínimo %<minimum>s).',
      pay_with: 'Pagar com %<method>s', pay_error: 'Não conseguimos iniciar o pagamento. Confira o valor e tente de novo.',
      payment_processing: 'Estamos confirmando o seu pagamento. Esta página se atualiza sozinha.',
      payment_received: 'Pagamento recebido, obrigado! Vamos enviar o recibo.'
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
      email_thanks: 'Thank you.',
      view_document: 'View %<document>s', regards: 'Best regards,', message: '%<document>s %<number>s: %<url>s',
      receipt: 'Receipt', received_from: 'Received from', amount_received: 'Amount received', payment_date: 'Payment date',
      payment_method: 'Payment method', invoice_total: 'Invoice total', paid_to_date: 'Paid to date',
      receipt_statement: 'We received the sum of %<amount>s as payment of %<document>s.', pay_online: 'Pay online',
      amount_to_pay: 'Amount to pay', pay_amount_hint: 'You can pay the full balance or part of it (minimum %<minimum>s).',
      pay_with: 'Pay with %<method>s', pay_error: 'We could not start the payment. Check the amount and try again.',
      payment_processing: 'We are confirming your payment. This page refreshes on its own.',
      payment_received: 'Payment received, thank you! We will send you the receipt.'
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

  # Separador e milhar vêm daqui, não do I18n: o idioma é do documento, e o
  # Chatwoot nem tem o locale pt-BR (o dele é pt_BR).
  def self.money(amount, currency, language)
    symbol = { 'USD' => '$', 'BRL' => 'R$', 'EUR' => '€' }.fetch(currency)
    separator, delimiter = { 'es' => [',', '.'], 'pt' => [',', '.'], 'en' => ['.', ','] }.fetch(language)
    formatted = ActiveSupport::NumberHelper.number_to_currency(amount, unit: '', precision: 2, separator: separator,
                                                                       delimiter: delimiter).strip
    "#{symbol} #{formatted}"
  end

  def self.date(value, language)
    return '' unless value

    language == 'en' ? value.strftime('%m/%d/%Y') : value.strftime('%d/%m/%Y')
  end
end
