// Campanhas por QR: o ritmo que uma campanha nova já nasce com (o mesmo do
// backend, Outreach::Pacing::DEFAULTS), o piso do intervalo e os estados.
export const PACING_DEFAULTS = {
  window_start: 8,
  window_end: 20,
  days: [1, 2, 3, 4, 5, 6],
  interval_min: 20,
  interval_max: 45,
  max_per_hour: 30,
  max_per_day: null,
  batch_size: 10,
  batch_pause_min: 5,
  batch_pause_max: 15,
};

export const INTERVAL_FLOOR = 15;
export const MAX_VARIANTS = 3;
export const WEEKDAYS = [0, 1, 2, 3, 4, 5, 6];

export const STATUS_CLASSES = {
  draft: 'bg-n-slate-3 text-n-slate-11',
  ready: 'bg-n-blue-3 text-n-blue-11',
  running: 'bg-n-teal-3 text-n-teal-11',
  paused: 'bg-n-amber-3 text-n-amber-11',
  completed: 'bg-n-slate-3 text-n-slate-12',
  cancelled: 'bg-n-ruby-3 text-n-ruby-11',
};
