-- Resposta do bot em bolhas com "digitando" (no Responde do n8n), por rota.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_split_replies.sql
--
-- Nula = o Guard decide pelo tipo do canal no Chatwoot (WhatsApp Cloud,
-- Instagram, Messenger, SMS, Telegram, Line ligados; widget e e-mail
-- desligados). O OpenWA e canal API, o mesmo tipo da voz e do site da DaGente,
-- entao o tipo nao basta: a rota dele grava true. O provision do OpenWA ja
-- grava para as rotas novas; o update abaixo cobre as que existem.

alter table bot_channel_routes add column if not exists split_replies boolean;

update bot_channel_routes set split_replies = true
where (chatwoot_account_id, chatwoot_inbox_id) in ((1, 2), (1, 14), (1, 30), (2, 31));
