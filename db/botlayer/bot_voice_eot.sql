-- O limiar que decide quando o turno de quem liga acabou.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_voice_eot.sql
--
-- Por que virou campo: com o coletor de métricas consertado, a espera do
-- EndOfTurn apareceu como ~0,8 s de silêncio com quem ligou já calado — o maior
-- pedaço da latência que é nosso. O limiar estava chumbado no código, então
-- procurar o ponto certo exigia um deploy por tentativa, e o custo de mexer nele
-- era invisível. Agora é uma chamada por tentativa, sem deploy.

begin;

-- Confiança de fim de turno, não milissegundos de silêncio: o Flux acumula
-- certeza enquanto ouve, e este é o ponto em que ele para de esperar.
--
-- 0.7 é o padrão da Deepgram e aqui fragmentava a fala — "Doutor Juan" chegou
-- como 'Doutor,' + 'one.' e custou três idas e voltas para capturar um nome.
-- 0.8 é o que segura quem soletra um e-mail letra por letra. Mais alto que isso
-- some com a conversa; o teto do CHECK existe para que ninguém descubra isso
-- com um cliente na linha.
alter table bot_personas
  add column if not exists voice_eot_threshold numeric(3, 2) not null default 0.80;

alter table bot_personas
  drop constraint if exists bot_personas_voice_eot_threshold_range;

alter table bot_personas
  add constraint bot_personas_voice_eot_threshold_range
  check (voice_eot_threshold >= 0.50 and voice_eot_threshold <= 0.95);

comment on column bot_personas.voice_eot_threshold is
  'Confiança que o Deepgram Flux exige para declarar encerrado o turno de quem liga. Baixo demais corta quem faz pausa ou soletra; alto demais deixa a pessoa esperando em silêncio. Só vale em modelos flux-*.';

-- A view precisa ser reescrita inteira, e a coluna nova vai no fim: um
-- CREATE OR REPLACE VIEW só aceita acréscimo no final, reordenar exige DROP.
create or replace view bot_persona_resolved
with (security_invoker = true) as
with knowledge as (
  select
    p.id as persona_id,
    string_agg(d.content, E'\n\n---\n\n' order by d.priority, d.slug) as knowledge_md
  from bot_personas p
  join bot_knowledge_docs d
    on d.is_active
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
  p.voice_eot_threshold
from bot_personas p
left join knowledge k on k.persona_id = p.id;

commit;
