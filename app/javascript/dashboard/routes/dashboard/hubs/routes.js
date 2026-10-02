import { frontendURL } from '../../../helper/URLHelper';
import HubIndex from './pages/HubIndex.vue';
import { HUBS } from './catalog';

export const routes = Object.entries(HUBS).map(([hub, { permissions }]) => ({
  path: frontendURL(`accounts/:accountId/${hub}`),
  name: `${hub}_hub`,
  component: HubIndex,
  meta: { hub, permissions },
}));
