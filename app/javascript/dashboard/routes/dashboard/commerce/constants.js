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
    const gross = round(Number(line.quantity || 0) * Number(line.unit_price || 0));
    const discount = round((gross * Number(line.discount_percent || 0)) / 100);
    const net = gross - discount;
    const rate = Number(line.tax_rate || 0);
    let tax = 0;
    if (taxMode === 'exclusive') tax = round((net * rate) / 100);
    if (taxMode === 'inclusive' && rate) tax = round(net - net / (1 + rate / 100));
    totals.subtotal += gross;
    totals.discount += discount;
    totals.tax += tax;
    totals.total += taxMode === 'exclusive' ? net + tax : net;
  });
  return totals;
};
