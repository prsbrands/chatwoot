import { frontendURL } from '../../../helper/URLHelper';
import CasesIndex from './pages/CasesIndex.vue';
import CaseShow from './pages/CaseShow.vue';
import CasesSettings from './pages/CasesSettings.vue';
import CasesMetrics from './pages/CasesMetrics.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

// /cases/settings e /cases/metrics antes de /cases/:caseId, para não virarem
// um caso.
export const routes = [
  {
    path: frontendURL('accounts/:accountId/cases'),
    name: 'cases_index',
    component: CasesIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.CASES,
      permissions: ['administrator', 'agent'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/cases/settings'),
    name: 'cases_settings',
    component: CasesSettings,
    meta: {
      featureFlag: FEATURE_FLAGS.CASES,
      permissions: ['administrator'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/cases/metrics'),
    name: 'cases_metrics',
    component: CasesMetrics,
    meta: {
      featureFlag: FEATURE_FLAGS.CASES,
      permissions: ['administrator', 'agent'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/cases/:caseId'),
    name: 'case_show',
    component: CaseShow,
    meta: {
      featureFlag: FEATURE_FLAGS.CASES,
      permissions: ['administrator', 'agent'],
    },
  },
];
