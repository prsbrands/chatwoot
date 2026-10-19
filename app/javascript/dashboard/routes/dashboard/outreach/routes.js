import { frontendURL } from '../../../helper/URLHelper';
import OutreachIndex from './pages/OutreachIndex.vue';
import OutreachNew from './pages/OutreachNew.vue';
import OutreachShow from './pages/OutreachShow.vue';
import OutreachSuppressions from './pages/OutreachSuppressions.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

// /outreach/new e /outreach/exclusions antes de /outreach/:campaignId, para não
// virarem uma campanha.
const meta = {
  featureFlag: FEATURE_FLAGS.OUTREACH,
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/outreach'),
    name: 'outreach_index',
    component: OutreachIndex,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/outreach/new'),
    name: 'outreach_new',
    component: OutreachNew,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/outreach/exclusions'),
    name: 'outreach_suppressions',
    component: OutreachSuppressions,
    meta,
  },
  {
    path: frontendURL('accounts/:accountId/outreach/:campaignId'),
    name: 'outreach_show',
    component: OutreachShow,
    meta,
  },
];
