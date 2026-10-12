import { frontendURL } from '../../../helper/URLHelper';
import AiEvolutionIndex from './pages/AiEvolutionIndex.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/ai-evolution'),
    name: 'ai_evolution_index',
    component: AiEvolutionIndex,
    meta: {
      featureFlag: FEATURE_FLAGS.AI_EVOLUTION,
      permissions: ['administrator'],
    },
  },
];
