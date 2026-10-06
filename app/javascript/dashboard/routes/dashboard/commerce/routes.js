import { frontendURL } from '../../../helper/URLHelper';
import CatalogIndex from './pages/CatalogIndex.vue';
import CompanyIndex from './pages/CompanyIndex.vue';
import DocumentsIndex from './pages/DocumentsIndex.vue';
import DocumentEditor from './pages/DocumentEditor.vue';
import SubscriptionsIndex from './pages/SubscriptionsIndex.vue';
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
  {
    path: frontendURL('accounts/:accountId/documents'),
    name: 'commerce_documents',
    component: DocumentsIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.COMMERCE,
      permissions: ['administrator', 'agent'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/subscriptions'),
    name: 'commerce_subscriptions',
    component: SubscriptionsIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.COMMERCE,
      permissions: ['administrator', 'agent'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/documents/:documentId'),
    name: 'commerce_document',
    component: DocumentEditor,
    meta: {
      featureFlag: FEATURE_FLAGS.COMMERCE,
      permissions: ['administrator', 'agent'],
    },
  },
];
