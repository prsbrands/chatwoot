-- Jev (TypeSafe, modelo System One): decisões rápidas e baratas ao lado do LLM
-- do bot. Não conversa com o cliente — decide se o LLM precisa rodar, com que
-- modelo e com que pedaço da base de conhecimento, se a conversa vai para um
-- humano, e se a resposta pronta pode sair.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_jev.sql
--
-- A chave é da conta, como as de LLM em bot_providers, e mora na mesma linha
-- que o Guard do n8n já lê a cada mensagem (bot_account_settings): nenhuma
-- consulta a mais por mensagem. Quem escreve é só o Rails (JevController);
-- RLS ligado sem policies, então só a service_role lê.
--
-- `jev` guarda o que a tela liga e desliga:
--   { enabled, consent: {user_id, name, at}, activities: {<id>: observing|deciding|off},
--     review_rules: [..] }

alter table bot_account_settings
  add column if not exists jev_api_key text,
  add column if not exists jev_key_checked_at timestamptz,
  add column if not exists jev jsonb not null default '{}'::jsonb;

-- Modelo por mensagem: o Jev classifica a mensagem como simples, normal ou
-- delicada. Simples vai para o modelo leve, delicada para o forte; sem o campo
-- preenchido, fica o modelo de sempre. Mesmo provider da persona.
alter table bot_personas
  add column if not exists light_model text,
  add column if not exists strong_model text;

-- Uma linha por chamada ao Jev (fase `input`, antes do LLM, ou `review`,
-- depois dele). Sem o texto do cliente: só o que o Jev respondeu, o que foi
-- feito e quanto custou. `decisions` é um objeto por atividade:
--   { <id>: { state, value, confidence, signal, acted, rule, agreed } }
-- `signal` = o Jev agiria; `acted` = agiu de fato (atividade decidindo);
-- `rule` / `agreed` só onde existe uma regra atual para comparar.
create table if not exists bot_jev_calls (
  id bigint generated always as identity primary key,
  chatwoot_account_id integer not null,
  chatwoot_conversation_id integer,
  chatwoot_message_id integer,
  phase text not null check (phase in ('input', 'review')),
  model text,
  latency_ms integer,
  input_tokens integer,
  status text not null check (status in ('ok', 'error', 'skipped')),
  error text,
  decisions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists bot_jev_calls_account_created
  on bot_jev_calls (chatwoot_account_id, created_at desc);

alter table bot_jev_calls enable row level security;

-- Retenção: 90 dias. Sem pg_cron nesta instalação, a poda roda na própria
-- escrita — uma vez por comando, pelo índice acima, só da conta que escreveu.
create or replace function bot_jev_calls_prune() returns trigger
language plpgsql as $$
begin
  delete from bot_jev_calls c
  using (select distinct chatwoot_account_id from new_rows) n
  where c.chatwoot_account_id = n.chatwoot_account_id
    and c.created_at < now() - interval '90 days';
  return null;
end $$;

drop trigger if exists trg_bot_jev_calls_prune on bot_jev_calls;
create trigger trg_bot_jev_calls_prune
  after insert on bot_jev_calls
  referencing new table as new_rows
  for each statement execute function bot_jev_calls_prune();

-- O que o cartão do Jev mostra: números dos últimos 7 dias e, por atividade,
-- os últimos 30. Custo em dólar pela tabela da TypeSafe (US$ 0,042 por milhão
-- de tokens de entrada; a saída é grátis) — sem arredondar, uma chamada custa
-- milésimos de centavo.
create or replace function bot_jev_summary(p_account integer)
returns jsonb
language sql stable as $$
  with week as (
    select * from bot_jev_calls
    where chatwoot_account_id = p_account and created_at > now() - interval '7 days'
  ),
  month as (
    select d.key as activity, d.value as v
    from bot_jev_calls c, jsonb_each(c.decisions) d
    where c.chatwoot_account_id = p_account
      and c.created_at > now() - interval '30 days'
      and c.status = 'ok'
  ),
  last_error as (
    select error, created_at from bot_jev_calls
    where chatwoot_account_id = p_account and status = 'error'
    order by created_at desc limit 1
  ),
  last_ok as (
    select max(created_at) as at from bot_jev_calls
    where chatwoot_account_id = p_account and status = 'ok'
  )
  select jsonb_build_object(
    'week', (select jsonb_build_object(
      'calls', count(*) filter (where status = 'ok'),
      'errors', count(*) filter (where status = 'error'),
      'cost_usd', coalesce(sum(input_tokens), 0) * 0.042 / 1000000,
      'avg_latency_ms', round(avg(latency_ms) filter (where status = 'ok')),
      'upset', count(*) filter (where (decisions -> 'mood' ->> 'signal')::boolean),
      'llm_calls_avoided', count(*) filter (where phase = 'input' and exists (
        select 1 from jsonb_each(decisions) d
        where (d.value ->> 'acted')::boolean and d.key in ('no_reply', 'human_request', 'mood', 'opt_out', 'manipulation')
      ))
    ) from week),
    'activities', coalesce((select jsonb_object_agg(activity, stats) from (
      select activity, jsonb_build_object(
        'runs', count(*),
        'signals', count(*) filter (where (v ->> 'signal')::boolean),
        'acted', count(*) filter (where (v ->> 'acted')::boolean),
        'compared', count(*) filter (where v ? 'agreed'),
        'agreed', count(*) filter (where (v ->> 'agreed')::boolean),
        'tokens_saved', coalesce(sum((v ->> 'tokens_saved')::integer), 0)
      ) as stats
      from month group by activity
    ) s), '{}'::jsonb),
    'last_error', (select to_jsonb(last_error) from last_error),
    'last_ok_at', (select at from last_ok)
  );
$$;

-- A view que o n8n lê ganha os dois modelos no fim — CREATE OR REPLACE VIEW
-- não aceita reordenar colunas. O resto é idêntico a bot_layer_per_account.sql.
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
  p.strong_model
from bot_channel_routes r
  join bot_personas p on p.id = r.persona_id
  left join knowledge k on k.persona_id = p.id
  left join bot_providers prov
    on prov.slug = coalesce(r.overrides ->> 'provider', p.provider)
   and prov.chatwoot_account_id = r.chatwoot_account_id and prov.is_active
  left join bot_providers prov_fb
    on prov_fb.slug = coalesce(p.fallback_provider, coalesce(r.overrides ->> 'provider', p.provider))
   and prov_fb.chatwoot_account_id = r.chatwoot_account_id and prov_fb.is_active;
