// Mesmas listas do Rails (Commerce::CURRENCIES, Commerce::Item::UNITS,
// Commerce::PaymentMethod kinds).
export const CURRENCIES = ['USD', 'BRL', 'EUR'];
export const UNITS = [
  'unit',
  'hour',
  'day',
  'week',
  'month',
  'm',
  'm2',
  'm3',
  'kg',
  'liter',
  'package',
  'project',
  'service',
];
export const KINDS = ['product', 'service'];
export const PAYMENT_KINDS = [
  'cash',
  'bank_transfer',
  'pix',
  'yappy',
  'card',
  'payment_link',
  'other',
];
export const IMAGE_TYPES = 'image/png,image/jpeg,image/webp';
export const MAX_IMAGES = 10;

export const formatPrice = (price, currency) =>
  new Intl.NumberFormat(undefined, { style: 'currency', currency }).format(
    Number(price)
  );

export const DOCUMENT_LANGUAGES = ['es', 'pt', 'en'];
export const DOCUMENT_KINDS = ['quote', 'invoice', 'receipt'];
// Mesmas regras do Commerce::Document#status_fits_kind.
export const DOCUMENT_STATUSES = {
  quote: ['draft', 'sent', 'accepted', 'declined', 'void'],
  invoice: ['draft', 'sent', 'partially_paid', 'paid', 'void'],
  receipt: ['draft', 'sent', 'void'],
};
export const PROVIDER_ENVIRONMENTS = ['sandbox', 'production'];
// Provedores de cobrança online (Commerce::PaymentProvider::AVAILABLE e
// CREDENTIALS): as credenciais pedidas (secret: campo de senha; optional: pode
// ficar em branco), as moedas aceitas e, no Mercado Pago, a chave secreta
// opcional dos webhooks.
export const ONLINE_PROVIDERS = {
  stripe: {
    fields: [{ key: 'secret_key', secret: true, placeholder: 'sk_test_…' }],
    currencies: ['USD', 'EUR', 'BRL'],
  },
  mercado_pago: {
    fields: [{ key: 'access_token', secret: true, placeholder: 'APP_USR-…' }],
    currencies: ['BRL'],
    webhookSecret: true,
  },
  yappy: {
    fields: [
      { key: 'merchant_id' },
      { key: 'secret_key', secret: true },
      { key: 'domain', optional: true, placeholder: 'https://' },
    ],
    currencies: ['USD'],
  },
};
export const TAX_MODES = ['exclusive', 'inclusive', 'exempt'];
export const STATUS_CLASSES = {
  draft: 'bg-n-slate-3 text-n-slate-11',
  sent: 'bg-n-blue-3 text-n-blue-11',
  accepted: 'bg-n-teal-3 text-n-teal-11',
  declined: 'bg-n-ruby-3 text-n-ruby-11',
  expired: 'bg-n-amber-3 text-n-amber-11',
  overdue: 'bg-n-amber-3 text-n-amber-11',
  partially_paid: 'bg-n-amber-3 text-n-amber-11',
  paid: 'bg-n-teal-3 text-n-teal-11',
  void: 'bg-n-slate-3 text-n-slate-10',
};

// Mesma conta do Commerce::DocumentTotals (Rails), para a tela mostrar os
// totais enquanto a pessoa digita; o que vale é o que o servidor devolve.
const round = value => Math.round((value + Number.EPSILON) * 100) / 100;
export const documentTotals = (lines, taxMode) => {
  const totals = { subtotal: 0, discount: 0, tax: 0, total: 0 };
  lines.forEach(line => {
    const gross = round(
      Number(line.quantity || 0) * Number(line.unit_price || 0)
    );
    const discount = round((gross * Number(line.discount_percent || 0)) / 100);
    const net = gross - discount;
    const rate = Number(line.tax_rate || 0);
    let tax = 0;
    if (taxMode === 'exclusive') tax = round((net * rate) / 100);
    if (taxMode === 'inclusive' && rate)
      tax = round(net - net / (1 + rate / 100));
    totals.subtotal += gross;
    totals.discount += discount;
    totals.tax += tax;
    totals.total += taxMode === 'exclusive' ? net + tax : net;
  });
  return totals;
};
