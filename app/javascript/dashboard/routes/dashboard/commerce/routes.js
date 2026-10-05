import { frontendURL } from '../../../helper/URLHelper';
import CatalogIndex from './pages/CatalogIndex.vue';
import CompanyIndex from './pages/CompanyIndex.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/catalog'),
    name: 'commerce_catalog',
    component: CatalogIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.COMMERCE,
      permissions: ['administrator', 'agent'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/company'),
    name: 'commerce_company',
    component: CompanyIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.COMMERCE,
      permissions: ['administrator'],
    },
  },
];
