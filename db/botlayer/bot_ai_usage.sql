-- Uso de IA por conta e teto mensal (1.11.0).
--
-- bot_interactions, onde o nó Log grava cada resposta do bot desde 08/08, não
-- sabia de que conta era (só o número da conversa, que se repete entre contas)
-- e deixava cost_usd vazio. Agora o workflow grava a conta, o tipo da chamada
-- e o custo que o OpenRouter devolve em usage.cost:
--   reply    — a resposta ao cliente (nó Log);
--   briefing — o resumo da passagem para humano (nó Passagem);
--   followup — a retomada por silêncio (workflow CortexGen Follow-up).
-- O Jev continua em bot_jev_calls, com o custo pela tabela da TypeSafe.
--
-- O teto (ai_monthly_budget_usd, nulo = sem teto) é do Super Admin. O Guard e o
-- Candidatos do follow-up leem bot_ai_month_spend: com o mês no teto, a
-- mensagem nova vai para a equipe sem chamar LLM nenhum.
--
-- Rodar no supabase-db ANTES de publicar os workflows: o Log grava as colunas
-- novas, e o PostgREST recusa coluna que não existe (o bot inteiro para).

alter table bot_interactions add column if not exists chatwoot_account_id integer;
alter table bot_interactions add column if not exists kind text not null default 'reply';
alter table bot_interactions drop constraint if exists bot_interactions_kind_check;
alter table bot_interactions add constraint bot_interactions_kind_check check (kind in ('reply', 'briefing', 'followup'));

update bot_interactions i
set chatwoot_account_id = p.chatwoot_account_id
from bot_personas p
where i.persona_id = p.id and i.chatwoot_account_id is null;

create index if not exists bot_interactions_account_created on bot_interactions (chatwoot_account_id, created_at);

alter table bot_account_settings add column if not exists ai_monthly_budget_usd numeric(10, 2)
  check (ai_monthly_budget_usd is null or ai_monthly_budget_usd >= 0);

-- Gasto do mês corrente (UTC): LLM com preço conhecido + Jev. Chamada sem
-- cost_usd (provedor próprio da conta, que não devolve custo) conta zero.
create or replace function bot_ai_month_spend(p_account integer)
returns numeric
language sql stable as $$
  select
    coalesce((select sum(cost_usd) from bot_interactions
              where chatwoot_account_id = p_account and created_at >= date_trunc('month', now())), 0)
    + coalesce((select sum(input_tokens) * 0.042 / 1000000 from bot_jev_calls
                where chatwoot_account_id = p_account and created_at >= date_trunc('month', now())), 0);
$$;

-- O que a tela Uso de IA mostra para um intervalo.
create or replace function bot_ai_usage(p_account integer, p_from timestamptz, p_to timestamptz)
returns jsonb
language sql stable as $$
  with llm as (
    select * from bot_interactions
    where chatwoot_account_id = p_account and created_at >= p_from and created_at < p_to
  ),
  jev as (
    select created_at, input_tokens * 0.042 / 1000000 as cost from bot_jev_calls
    where chatwoot_account_id = p_account and created_at >= p_from and created_at < p_to
  ),
  dias as (
    select date_trunc('day', created_at) as day, sum(coalesce(cost_usd, 0)) as llm, 0::numeric as jev, count(*) as calls
    from llm group by 1
    union all
    select date_trunc('day', created_at), 0, sum(cost), 0 from jev group by 1
  )
  select jsonb_build_object(
    'llm_usd', (select coalesce(sum(cost_usd), 0) from llm),
    'jev_usd', (select coalesce(sum(cost), 0) from jev),
    'calls', (select count(*) from llm),
    'unpriced_calls', (select count(*) from llm where cost_usd is null),
    'jev_calls', (select count(*) from jev),
    'conversations', (select count(distinct chatwoot_conversation_id) from llm where kind = 'reply'),
    'tokens_in', (select coalesce(sum(tokens_in), 0) from llm),
    'tokens_out', (select coalesce(sum(tokens_out), 0) from llm),
    'by_day', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'llm_usd', llm, 'jev_usd', jev, 'calls', calls) order by day)
                        from (select day, sum(llm) as llm, sum(jev) as jev, sum(calls) as calls from dias group by day) d), '[]'::jsonb),
    'by_kind', coalesce((select jsonb_object_agg(kind, jsonb_build_object('usd', usd, 'calls', calls))
                         from (select kind, sum(coalesce(cost_usd, 0)) as usd, count(*) as calls from llm group by kind) k), '{}'::jsonb),
    'by_model', coalesce((select jsonb_agg(jsonb_build_object('model', model, 'usd', usd, 'calls', calls, 'tokens_in', tin, 'tokens_out', tout) order by usd desc)
                          from (select coalesce(model, '?') as model, sum(coalesce(cost_usd, 0)) as usd, count(*) as calls,
                                       sum(tokens_in) as tin, sum(tokens_out) as tout
                                from llm group by 1) m), '[]'::jsonb),
    'month_spend_usd', bot_ai_month_spend(p_account),
    'budget_usd', (select ai_monthly_budget_usd from bot_account_settings where chatwoot_account_id = p_account)
  );
$$;
