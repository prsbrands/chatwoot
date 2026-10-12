// Os valores que a API aceita (Cases::Case e Cases::Type).
export const ACTIVE_STATUSES = ['open', 'in_progress', 'waiting_customer'];
export const STATUSES = [...ACTIVE_STATUSES, 'resolved', 'canceled'];
export const PRIORITIES = ['low', 'normal', 'high', 'urgent'];
export const OUTCOMES = [
  'solved',
  'not_applicable',
  'duplicate',
  'no_response',
];
export const FIELD_TYPES = ['text', 'number', 'date', 'select', 'boolean'];
export const AI_MODES = ['off', 'continue', 'handoff'];
export const TYPE_COLORS = [
  '#3B82F6',
  '#EF4444',
  '#10B981',
  '#F59E0B',
  '#8B5CF6',
  '#EC4899',
  '#14B8A6',
  '#6B7280',
];

// Ações de cada situação, na ordem dos botões do caso.
export const ACTIONS_BY_STATUS = {
  open: ['start', 'wait_customer', 'resolve', 'cancel'],
  in_progress: ['wait_customer', 'resolve', 'cancel'],
  waiting_customer: ['start', 'resolve', 'cancel'],
  resolved: ['reopen'],
  canceled: ['reopen'],
};

export const PRIORITY_CLASSES = {
  low: 'text-n-slate-11',
  normal: 'text-n-slate-11',
  high: 'text-n-amber-11',
  urgent: 'text-n-ruby-11',
};

export const STATUS_CLASSES = {
  open: 'bg-n-blue-3 text-n-blue-11',
  in_progress: 'bg-n-violet-3 text-n-violet-11',
  waiting_customer: 'bg-n-amber-3 text-n-amber-11',
  resolved: 'bg-n-teal-3 text-n-teal-11',
  canceled: 'bg-n-slate-3 text-n-slate-11',
};

// Chave do campo próprio a partir do rótulo: "Nº do pedido" → "n_do_pedido".
export const fieldKey = label =>
  label
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^[^a-z]+|_+$/g, '')
    .slice(0, 40) || 'field';
