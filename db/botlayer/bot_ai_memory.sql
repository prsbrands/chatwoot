-- Memória da IA por contato (1.20.0).
--
-- O workflow "CortexGen Memória" grava o LLM que atualiza a memória do cliente
-- em bot_interactions com kind 'memory': entra no Uso de IA e no teto mensal
-- como os outros. A memória em si fica no Rails (ai_memory_summaries,
-- ai_memory_facts).
--
-- Rodar no supabase-db ANTES de publicar o workflow: com a constraint antiga o
-- registro do uso falha e o GravaMemoria para na primeira conversa.

alter table bot_interactions drop constraint if exists bot_interactions_kind_check;
alter table bot_interactions add constraint bot_interactions_kind_check
  check (kind in ('reply', 'briefing', 'followup', 'memory'));
