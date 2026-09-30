-- Bloco 2 (0.10.0): follow-up quando o cliente some, com anti-ban no OpenWA.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_followups.sql
--
-- A varredura e o workflow "CortexGen Follow-up" do n8n (ops/n8n/followup_*.js),
-- a cada 15 min. Config na persona (Bot Personas): horas de silencio (nula =
-- desligado) e quantos follow-ups por silencio.

alter table bot_personas add column if not exists followup_after_hours numeric;
alter table bot_personas add column if not exists max_followups integer not null default 2;

-- Idade do numero para o teto diario de follow-ups (20 -> 50 -> 100 -> 200 por
-- dia nos primeiros 30 dias). Nula = numero novo, o teto mais baixo. O
-- provision do OpenWA grava a data do dia; as rotas existentes recebem a data
-- de criacao do canal no Chatwoot.
alter table bot_channel_routes add column if not exists number_activated_at date;
update bot_channel_routes set number_activated_at = v.d::date
from (values (1, 2, '2026-08-07'), (1, 14, '2026-08-08'), (1, 30, '2026-09-11'), (2, 31, '2026-09-19')) as v (a, i, d)
where chatwoot_account_id = v.a and chatwoot_inbox_id = v.i and number_activated_at is null;

-- Uma linha por SILENCIO: a ancora e a ultima mensagem do cliente. Cliente que
-- responde e some de novo abre outra linha (ancora nova); sem resposta, a
-- linha esgota e nao volta. E o cooldown: no DeskComm, uma varredura sem ele
-- reinscreveu o mesmo contato 32 vezes em 9 h.
create table if not exists bot_followups (
  id bigint generated always as identity primary key,
  chatwoot_account_id integer not null,
  chatwoot_inbox_id integer not null,
  chatwoot_conversation_id integer not null,   -- display_id, o da API
  chatwoot_contact_id integer not null,
  anchor_message_id bigint not null,           -- ultima mensagem do cliente
  status text not null default 'active'
    check (status in ('active', 'replied', 'exhausted', 'declined', 'vetoed', 'cancelled')),
  attempts integer not null default 0,
  vetoes integer not null default 0,
  decided_by text,                             -- jev | llm
  last_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chatwoot_account_id, chatwoot_conversation_id, anchor_message_id)
);

-- Um follow-up vivo por contato na conta, mesmo com duas conversas abertas.
create unique index if not exists bot_followups_one_live
  on bot_followups (chatwoot_account_id, chatwoot_contact_id) where status = 'active';

-- Cada envio: o teto diario conta daqui, e o veto de texto parecido compara
-- com os ultimos 20 desta inbox (o numero de WhatsApp).
create table if not exists bot_followup_sends (
  id bigint generated always as identity primary key,
  followup_id bigint not null references bot_followups (id) on delete cascade,
  chatwoot_account_id integer not null,
  chatwoot_inbox_id integer not null,
  content text not null,
  sent_at timestamptz not null default now()
);
create index if not exists bot_followup_sends_inbox on bot_followup_sends (chatwoot_inbox_id, sent_at desc);

alter table bot_followups enable row level security;
alter table bot_followup_sends enable row level security;

alter table bot_jev_calls drop constraint if exists bot_jev_calls_phase_check;
alter table bot_jev_calls add constraint bot_jev_calls_phase_check
  check (phase in ('input', 'review', 'team', 'followup'));

-- A view que a varredura le ganha quatro colunas no fim (CREATE OR REPLACE VIEW
-- nao aceita reordenar). O resto e identico a bot_jev.sql.
create or replace view bot_route_resolved
with (security_invoker = true) as
with knowledge as (
  select
    p.id as persona_id,
    string_agg(d.content, E'\n\n---\n\n' order by d.priority, d.slug) as knowledge_md
  from bot_personas p
  join bot_knowledge_docs d
    on d.is_active
   and d.chatwoot_account_id = p.chatwoot_account_id
   and (d.is_global or exists (
         select 1 from bot_persona_knowledge pk
         where pk.persona_id = p.id and pk.doc_id = d.id))
  group by p.id
)
select
  r.chatwoot_account_id,
  r.chatwoot_inbox_id,
  r.channel_label,
  r.channel_kind,
  r.business_hours,
  r.chatwoot_agent_bot_id,
  p.id as persona_id,
  p.slug as persona_slug,
  p.display_name,
  p.system_prompt,
  k.knowledge_md,
  case
    when k.knowledge_md is null then p.system_prompt
    else p.system_prompt || E'\n\n---\n\n# BASE DE CONOCIMIENTO\n\n' || k.knowledge_md
  end as composed_prompt,
  p.handoff_rules,
  coalesce(r.overrides ->> 'provider', p.provider) as provider,
  coalesce(r.overrides ->> 'model', p.model) as model,
  coalesce(r.overrides ->> 'fallback_model', p.fallback_model) as fallback_model,
  coalesce((r.overrides ->> 'temperature')::numeric, p.temperature) as temperature,
  coalesce((r.overrides ->> 'max_tokens')::integer, p.max_tokens) as max_tokens,
  r.is_active and p.is_active as is_active,
  prov.base_url as provider_base_url,
  prov.api_style as provider_api_style,
  prov.api_key as provider_api_key,
  coalesce(p.fallback_provider, coalesce(r.overrides ->> 'provider', p.provider)) as fallback_provider,
  prov_fb.base_url as fallback_provider_base_url,
  prov_fb.api_style as fallback_provider_api_style,
  prov_fb.api_key as fallback_provider_api_key,
  p.light_model,
  p.strong_model,
  r.split_replies,
  p.followup_after_hours,
  p.max_followups,
  r.number_activated_at
from bot_channel_routes r
  join bot_personas p on p.id = r.persona_id
  left join knowledge k on k.persona_id = p.id
  left join bot_providers prov
    on prov.slug = coalesce(r.overrides ->> 'provider', p.provider)
   and prov.chatwoot_account_id = r.chatwoot_account_id and prov.is_active
  left join bot_providers prov_fb
    on prov_fb.slug = coalesce(p.fallback_provider, coalesce(r.overrides ->> 'provider', p.provider))
   and prov_fb.chatwoot_account_id = r.chatwoot_account_id and prov_fb.is_active;
