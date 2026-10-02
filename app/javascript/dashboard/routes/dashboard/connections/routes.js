import { frontendURL } from '../../../helper/URLHelper';
import ConnectionsIndex from './pages/ConnectionsIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/connections'),
    name: 'connections_index',
    component: ConnectionsIndex,
    meta: {
      permissions: ['administrator'],
    },
  },
];
