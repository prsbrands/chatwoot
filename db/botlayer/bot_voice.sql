-- Camada de bots: o que a voz precisa além do que o bot de texto já usa.
--
-- Rodar no Supabase (supabase.cortexgen.cloud):
--   docker exec -i supabase-db psql -U postgres -d postgres < db/botlayer/bot_voice.sql
--
-- `bot_route_resolved` não é tocada de propósito: é o que o workflow de texto
-- consome em produção, e um CREATE OR REPLACE nela só aceitaria colunas novas
-- no fim. A voz ganha uma view própria.

begin;

-- 1. Um fornecedor pode servir mais de uma coisa -------------------------------
--
-- O plano previa uma coluna `kind` singular, mas a mesma conta de OpenAI faz
-- LLM, STT e TTS, e a mesma de OpenRouter faz LLM e STT (Deepgram nova-3). Com
-- coluna singular, a mesma chave teria que virar linhas duplicadas — e a chave
-- é justamente o que não se quer copiar. Daí o array.

alter table bot_providers
  add column if not exists kinds text[] not null default '{llm}';

alter table bot_providers
  drop constraint if exists bot_providers_kinds_valid;

alter table bot_providers
  add constraint bot_providers_kinds_valid
  check (kinds <@ array['llm', 'stt', 'tts'] and array_length(kinds, 1) >= 1);

-- O OpenRouter já transcreve: `deepgram/nova-3` por /api/v1/audio/transcriptions,
-- US$0,0043/min, mesma chave do LLM. Por isso não há preset de Deepgram direto:
-- seria uma segunda conta para o mesmo modelo pelo mesmo preço.
update bot_providers set kinds = '{llm,stt}' where slug = 'openrouter';

-- ElevenLabs e Deepgram não falam nem OpenAI nem Anthropic — cada um tem
-- protocolo próprio, e é por ele que o áudio trafega em streaming. Fingir que
-- são 'openai' faria a linha passar no CHECK e quebrar em quem lê o campo.
alter table bot_providers
  drop constraint if exists bot_providers_api_style_check;

alter table bot_providers
  add constraint bot_providers_api_style_check
  check (api_style = any (array['openai', 'anthropic', 'elevenlabs', 'deepgram']));

-- 2. Como a persona soa --------------------------------------------------------
--
-- Colunas anuláveis na própria persona em vez de tabela nova: quem lê isso é
-- uma chamada telefônica em curso, e um join a mais é latência num caminho onde
-- ela é o produto. Persona sem essas colunas segue sendo persona de texto.

alter table bot_personas
  add column if not exists stt_provider text,
  add column if not exists stt_model text,
  add column if not exists tts_provider text,
  add column if not exists tts_voice_id text,
  add column if not exists tts_model text,
  add column if not exists voice_language text,
  add column if not exists voice_first_message text,
  -- Os três tempos que definem a sensação da conversa.
  add column if not exists voice_greeting_delay_ms integer not null default 300,
  add column if not exists voice_endpoint_ms integer not null default 600,
  add column if not exists voice_interruptible boolean not null default true;

comment on column bot_personas.voice_greeting_delay_ms is
  'Espera antes do bot falar quando a chamada conecta. Curto demais e ele fala por cima do "alô".';
comment on column bot_personas.voice_endpoint_ms is
  'Silêncio que encerra o turno do cliente. Curto demais corta quem pensa no meio da frase; longo demais parece surdez.';
comment on column bot_personas.voice_interruptible is
  'Se o cliente falando por cima interrompe a fala do bot (barge-in).';

-- 3. Persona resolvida por slug ------------------------------------------------
--
-- A rota de voz é por número de telefone, no Postgres do Chatwoot — não por
-- inbox, que é a chave de `bot_route_resolved`. O que a chamada precisa é da
-- persona com a base de conhecimento já concatenada, e é só isso que esta view
-- entrega. As credenciais de fornecedor são resolvidas do lado do Rails, que já
-- sabe a conta e já lê `bot_providers` filtrando por ela.

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
  p.voice_interruptible
from bot_personas p
left join knowledge k on k.persona_id = p.id;

commit;
