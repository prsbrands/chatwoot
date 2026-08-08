import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import IntegrationHooks from './IntegrationHooks.vue';
import Index from './Index.vue';
import Webhook from './Webhooks/Index.vue';
import DashboardApps from './DashboardApps/Index.vue';
import Slack from './Slack.vue';
import Linear from './Linear.vue';
import Notion from './Notion.vue';
import Shopify from './Shopify.vue';
import Openwa from './Openwa/Index.vue';
import Botlayer from './Botlayer/Index.vue';
import AiProviders from './AiProviders/Index.vue';
import BotlayerPersonaEditor from './Botlayer/PersonaEditor.vue';
import BotlayerKnowledgeEditor from './Botlayer/KnowledgeEditor.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/integrations'),
      component: SettingsWrapper,
      props: {},
      children: [
        {
          path: '',
          name: 'settings_applications',
          component: Index,
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
        },
        {
          path: 'dashboard_apps',
          component: DashboardApps,
          name: 'settings_integrations_dashboard_apps',
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
        },
        {
          path: 'webhook',
          component: Webhook,
          name: 'settings_integrations_webhook',
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
        },
        {
          path: 'openwa',
          component: Openwa,
          name: 'settings_integrations_openwa',
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
        },
        {
          path: 'ai_providers',
          component: AiProviders,
          name: 'settings_integrations_ai_providers',
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
        },
        {
          path: 'botlayer',
          component: Botlayer,
          name: 'settings_integrations_botlayer',
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/integrations'),
      component: SettingsWrapper,
      children: [
        {
          path: 'slack',
          name: 'settings_integrations_slack',
          component: Slack,
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
          props: route => ({ code: route.query.code }),
        },
        {
          path: 'linear',
          name: 'settings_integrations_linear',
          component: Linear,
          meta: {
            permissions: ['administrator'],
          },
          props: route => ({ code: route.query.code }),
        },
        {
          path: 'notion',
          name: 'settings_integrations_notion',
          component: Notion,
          meta: {
            permissions: ['administrator'],
          },
          props: route => ({ code: route.query.code }),
        },
        {
          path: 'shopify',
          name: 'settings_integrations_shopify',
          component: Shopify,
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
          props: route => ({ error: route.query.error }),
        },
        {
          path: ':integration_id',
          name: 'settings_applications_integration',
          component: IntegrationHooks,
          meta: {
            featureFlag: FEATURE_FLAGS.INTEGRATIONS,
            permissions: ['administrator'],
          },
          props: route => ({
            integrationId: route.params.integration_id,
          }),
        },
      ],
    },
    // Editores da camada de bots ficam fora do SettingsWrapper (max-w-5xl e
    // altura automática) para o prompt ocupar a tela inteira.
    {
      path: frontendURL(
        'accounts/:accountId/settings/integrations/botlayer/personas/:personaId'
      ),
      name: 'settings_integrations_botlayer_persona',
      component: BotlayerPersonaEditor,
      meta: {
        featureFlag: FEATURE_FLAGS.INTEGRATIONS,
        permissions: ['administrator'],
      },
    },
    {
      path: frontendURL(
        'accounts/:accountId/settings/integrations/botlayer/knowledge/:docId'
      ),
      name: 'settings_integrations_botlayer_knowledge',
      component: BotlayerKnowledgeEditor,
      meta: {
        featureFlag: FEATURE_FLAGS.INTEGRATIONS,
        permissions: ['administrator'],
      },
    },
  ],
};
