-- Persona e base de conhecimento passam a ser da conta, não do servidor.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_layer_per_account.sql
--
-- `bot_channel_routes` e `bot_providers` já eram por conta; persona e documento
-- ficaram de fora e são justamente o que o cliente escreve. Com o painel cedido
-- a uma segunda conta, o admin dela abriria a lista e editaria o `system_prompt`
-- da primeira — a lógica de negócio de outro cliente. Hoje só existe uma conta,
-- então isto é preventivo: no dia da segunda, já nasceria vazando.

begin;

-- 1. A coluna ---------------------------------------------------------------
--
-- Sem default: uma linha que chegue sem conta é bug de chamador, e falhar aqui
-- é melhor do que criar persona órfã que ninguém vê no painel.

alter table bot_personas add column if not exists chatwoot_account_id integer;
alter table bot_knowledge_docs add column if not exists chatwoot_account_id integer;

-- Tudo o que existe hoje é da conta 1 (PRS Global Business), a única.
update bot_personas set chatwoot_account_id = 1 where chatwoot_account_id is null;
update bot_knowledge_docs set chatwoot_account_id = 1 where chatwoot_account_id is null;

alter table bot_personas alter column chatwoot_account_id set not null;
alter table bot_knowledge_docs alter column chatwoot_account_id set not null;

-- 2. O slug é único dentro da conta, não no servidor -------------------------
--
-- Com o slug global, o segundo cliente que criasse uma persona "atendimento"
-- receberia erro de duplicado por causa de uma linha que ele não pode ver.

alter table bot_personas drop constraint if exists bot_personas_slug_key;
alter table bot_knowledge_docs drop constraint if exists bot_knowledge_docs_slug_key;

create unique index if not exists bot_personas_account_slug_key
  on bot_personas (chatwoot_account_id, slug);
create unique index if not exists bot_knowledge_docs_account_slug_key
  on bot_knowledge_docs (chatwoot_account_id, slug);

create index if not exists bot_personas_account_idx on bot_personas (chatwoot_account_id);
create index if not exists bot_knowledge_docs_account_idx on bot_knowledge_docs (chatwoot_account_id);

comment on column bot_personas.chatwoot_account_id is
  'Conta do Chatwoot dona da persona. O client PostgREST filtra por ela em toda leitura e escrita.';
comment on column bot_knowledge_docs.chatwoot_account_id is
  'Conta do Chatwoot dona do documento. `is_global` significa global DENTRO da conta.';

-- 3. `is_global` passa a significar global dentro da conta -------------------
--
-- Esta é a parte que não se vê: o documento global entra no prompt de todas as
-- personas, e sem o recorte por conta o texto de um cliente apareceria na boca
-- do bot de outro. As duas views ganham a mesma cláusula.

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
  prov_fb.api_key as fallback_provider_api_key
from bot_channel_routes r
  join bot_personas p on p.id = r.persona_id
  left join knowledge k on k.persona_id = p.id
  left join bot_providers prov
    on prov.slug = coalesce(r.overrides ->> 'provider', p.provider)
   and prov.chatwoot_account_id = r.chatwoot_account_id and prov.is_active
  left join bot_providers prov_fb
    on prov_fb.slug = coalesce(p.fallback_provider, coalesce(r.overrides ->> 'provider', p.provider))
   and prov_fb.chatwoot_account_id = r.chatwoot_account_id and prov_fb.is_active;

-- A view da voz resolve por slug, que agora só é único dentro da conta: sem
-- expor a conta aqui, o serviço de voz não teria como pedir a persona certa.
-- Coluna nova vai no fim — CREATE OR REPLACE VIEW não aceita reordenar.
create or replace view bot_persona_resolved
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
  p.id as persona_id,
  p.slug as persona_slug,
  p.display_name,
  p.is_active,
  case
    when k.knowledge_md is null then p.system_prompt
    else p.system_prompt || E'\n\n---\n\n# BASE DE CONOCIMIENTO\n\n' || k.knowledge_md
  end as composed_prompt,
  p.handoff_rules,
  p.provider,
  p.model,
  p.fallback_provider,
  p.fallback_model,
  p.temperature,
  p.max_tokens,
  p.stt_provider,
  p.stt_model,
  p.tts_provider,
  p.tts_voice_id,
  p.tts_model,
  p.voice_language,
  p.voice_first_message,
  p.voice_greeting_delay_ms,
  p.voice_endpoint_ms,
  p.voice_interruptible,
  p.stt_language,
  p.voice_wait_for_complete_turn,
  p.voice_interrupt_min_words,
  p.voice_eot_threshold,
  p.chatwoot_account_id
from bot_personas p
left join knowledge k on k.persona_id = p.id;

commit;
