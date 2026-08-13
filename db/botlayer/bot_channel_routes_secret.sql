-- O Guard do n8n valida a assinatura HMAC do webhook do Chatwoot contra uma
-- ÚNICA variável de ambiente (CHATWOOT_WEBHOOK_SECRET), copiada uma vez do
-- secret do bot da conta 1 (Nathan). Toda conta nova tem seu próprio
-- AgentBot com secret próprio — o Guard rejeitava (assinatura inválida) tudo
-- que não fosse da conta 1, em silêncio, e o bot nunca respondia.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_channel_routes_secret.sql
--
-- A coluna guarda o secret do AgentBot vinculado à rota, gravado pelo Rails
-- (RoutesController#create) sempre que a rota é criada/atualizada. O Guard
-- passa a resolver o secret certo por conta+inbox antes de verificar a
-- assinatura, em vez de um valor fixo.
--
-- RLS já está ligado sem policies nesta tabela — só a service_role lê, a
-- mesma proteção que já vale para bot_providers.api_key.

alter table bot_channel_routes add column if not exists chatwoot_agent_bot_secret text;
