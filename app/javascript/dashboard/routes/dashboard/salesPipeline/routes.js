import { frontendURL } from '../../../helper/URLHelper';
import PipelineIndex from './pages/PipelineIndex.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/pipeline'),
    name: 'sales_pipeline_index',
    component: PipelineIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.SALES_PIPELINE,
      permissions: ['administrator', 'agent'],
    },
  },
];
