-- Evolução da IA (1.24.0).
--
-- O workflow "CortexGen Evolução" grava o LLM que lê as conversas e propõe
-- mudanças na base e no prompt em bot_interactions com kind 'evolution': entra
-- no Uso de IA e no teto mensal como os outros. As propostas ficam no Rails
-- (ai_evolution_suggestions).
--
-- Rodar no supabase-db ANTES de publicar o workflow: com a constraint antiga o
-- registro do uso falha e o GravaEvolucao para na primeira conversa.

alter table bot_interactions drop constraint if exists bot_interactions_kind_check;
alter table bot_interactions add constraint bot_interactions_kind_check
  check (kind in ('reply', 'briefing', 'followup', 'memory', 'evolution'));
