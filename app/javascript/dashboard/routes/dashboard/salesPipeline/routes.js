import { frontendURL } from '../../../helper/URLHelper';
import PipelineIndex from './pages/PipelineIndex.vue';
import RadarIndex from './pages/RadarIndex.vue';
import TasksIndex from './pages/TasksIndex.vue';
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
  {
    path: frontendURL('accounts/:accountId/radar'),
    name: 'sales_radar_index',
    component: RadarIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.SALES_PIPELINE,
      permissions: ['administrator', 'agent'],
    },
  },
  {
    path: frontendURL('accounts/:accountId/tasks'),
    name: 'sales_tasks_index',
    component: TasksIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.SALES_PIPELINE,
      permissions: ['administrator', 'agent'],
    },
  },
];
