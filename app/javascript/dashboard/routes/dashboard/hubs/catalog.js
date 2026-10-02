// Os hubs "View all in …" do menu (o lib/navigation/catalogo.ts do CRM é o
// modelo): cada grupo lista TODAS as telas dele, separadas por jornada, com
// uma linha dizendo para que serve. O texto fica em i18n (HUBS.<hub>.…); quem
// pode ver cada card é a própria rota (permissão e feature flag do meta).
export const HUBS = {
  crm: {
    permissions: ['administrator', 'agent'],
    sections: [
      {
        id: 'DAY_TO_DAY',
        items: [
          {
            id: 'PIPELINE',
            icon: 'i-lucide-kanban',
            to: 'sales_pipeline_index',
          },
          { id: 'RADAR', icon: 'i-lucide-radar', to: 'sales_radar_index' },
          {
            id: 'CONTACTS',
            icon: 'i-lucide-contact',
            to: 'contacts_dashboard_index',
            query: { page: 1 },
          },
          {
            id: 'COMPANIES',
            icon: 'i-lucide-building-2',
            to: 'companies_dashboard_index',
            query: { page: 1 },
          },
          {
            id: 'CAMPAIGNS',
            icon: 'i-lucide-megaphone',
            to: 'campaigns_whatsapp_index',
          },
          {
            id: 'CANNED',
            icon: 'i-lucide-message-square-quote',
            to: 'canned_list',
          },
        ],
      },
      {
        id: 'PREPARE',
        items: [
          { id: 'LABELS', icon: 'i-lucide-tags', to: 'labels_list' },
          {
            id: 'ATTRIBUTES',
            icon: 'i-lucide-list-plus',
            to: 'attributes_list',
          },
          {
            id: 'AUTOMATIONS',
            icon: 'i-lucide-workflow',
            to: 'automation_list',
          },
          { id: 'MACROS', icon: 'i-lucide-square-play', to: 'macros_wrapper' },
        ],
      },
    ],
  },
  ai: {
    permissions: ['administrator'],
    sections: [
      {
        id: 'BUILD',
        items: [
          {
            id: 'PERSONAS',
            icon: 'i-lucide-bot',
            to: 'settings_integrations_botlayer',
            query: { tab: 'personas' },
          },
          {
            id: 'CHANNELS',
            icon: 'i-lucide-route',
            to: 'settings_integrations_botlayer',
            query: { tab: 'channels' },
          },
          {
            id: 'PROVIDERS',
            icon: 'i-lucide-key-round',
            to: 'settings_integrations_ai_providers',
          },
          {
            id: 'VOICE',
            icon: 'i-lucide-phone',
            to: 'settings_integrations_twilio',
          },
        ],
      },
      {
        id: 'TEACH',
        items: [
          {
            id: 'KNOWLEDGE',
            icon: 'i-lucide-book-open',
            to: 'settings_integrations_botlayer',
            query: { tab: 'knowledge' },
          },
        ],
      },
      {
        id: 'WATCH',
        items: [
          {
            id: 'JEV',
            icon: 'i-lucide-zap',
            to: 'settings_integrations_ai_providers',
          },
          {
            id: 'FOLLOWUPS',
            icon: 'i-lucide-repeat',
            to: 'settings_integrations_botlayer',
            query: { tab: 'personas' },
          },
          { id: 'BOT_REPORTS', icon: 'i-lucide-chart-bar', to: 'bot_reports' },
          {
            id: 'CONNECTIONS',
            icon: 'i-lucide-plug',
            to: 'connections_index',
          },
        ],
      },
    ],
  },
};
