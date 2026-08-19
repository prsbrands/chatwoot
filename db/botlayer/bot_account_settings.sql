-- O nó Historico do workflow n8n lê o histórico da conversa
-- (GET /accounts/:id/conversations/:id/messages) com um token de **User**,
-- não de Agent Bot — o token do bot não pode chamar messages#index
-- (BOT_ACCESSIBLE_ENDPOINTS não inclui esse endpoint, de propósito, ver
-- HANDOFF "Historico com 401"). Até aqui isso era um único credential fixo
-- no n8n, do usuário da conta 1 — qualquer outra conta caía em 401
-- "not authorized to access this account".
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_account_settings.sql
--
-- Por conta, não por rota: é um token de admin da própria conta, o mesmo
-- para qualquer inbox dela. RLS ligado sem policies, mesma proteção que já
-- vale para bot_providers.api_key e bot_channel_routes.chatwoot_agent_bot_secret
-- — só a service_role lê.
--
-- A linha NÃO é mais gravada à mão. Quem escreve é o Rails, nos dois caminhos
-- que criam rota de bot: RoutesController#ensure_chat_user_token (Bot Personas
-- → Channels) e Openwa::ProvisionService#create_bot_route (sessão de WhatsApp),
-- os dois via Botlayer::Client#upsert_account_settings. O backfill manual era
-- onde cada conta nova travava, sempre com o mesmo sintoma: bot mudo.

create table if not exists bot_account_settings (
  chatwoot_account_id integer primary key,
  chat_user_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table bot_account_settings enable row level security;

drop trigger if exists trg_bot_account_settings_updated_at on bot_account_settings;
create trigger trg_bot_account_settings_updated_at
  before update on bot_account_settings
  for each row execute function bot_set_updated_at();
