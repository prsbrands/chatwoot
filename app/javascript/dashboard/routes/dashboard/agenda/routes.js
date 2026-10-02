import { frontendURL } from '../../../helper/URLHelper';
import AgendaIndex from './pages/AgendaIndex.vue';

// Sem feature flag: toda conta tem Agenda e a conexão com o Google.
export const routes = [
  {
    path: frontendURL('accounts/:accountId/agenda'),
    name: 'agenda_index',
    component: AgendaIndex,
    meta: {
      permissions: ['administrator', 'agent'],
    },
  },
];
