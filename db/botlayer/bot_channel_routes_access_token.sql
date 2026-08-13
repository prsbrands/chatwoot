-- Mesmo problema do secret do webhook (bot_channel_routes_secret.sql), num
-- lugar diferente: os nós Responde e Handoff do n8n postam de volta no
-- Chatwoot autenticados como o AgentBot, com um credential FIXO (token do
-- bot Nathan, conta 1). account_accessible_for_bot? (ensure_current_account_helper.rb)
-- só aceita o token de um bot cuja account_id bate com a conta da URL, ou que
-- tenha AgentBotInbox nela — o token do Nathan nunca vai servir pra conta
-- dagente. Mesma classe de bug do secret; resolvido do mesmo jeito.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_channel_routes_access_token.sql

alter table bot_channel_routes add column if not exists chatwoot_agent_bot_access_token text;
