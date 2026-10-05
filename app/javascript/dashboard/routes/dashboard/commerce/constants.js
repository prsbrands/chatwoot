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
