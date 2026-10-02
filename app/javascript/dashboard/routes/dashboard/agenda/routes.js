import { frontendURL } from '../../../helper/URLHelper';
import AgendaIndex from './pages/AgendaIndex.vue';
import AgendaSettings from './pages/AgendaSettings.vue';

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
  {
    path: frontendURL('accounts/:accountId/agenda/settings'),
    name: 'agenda_settings',
    component: AgendaSettings,
    meta: {
      permissions: ['administrator', 'agent'],
    },
  },
];
