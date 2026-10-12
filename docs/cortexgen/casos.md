# Casos — desenho

Módulo do CortexGen Chat (MIT, código nosso) para acompanhar o que o cliente pediu e que não se resolve na hora: uma dúvida que depende de alguém da empresa, um problema, uma solicitação, uma reclamação. O caso tem dono, prazo e desfecho, e pode passar por várias conversas e canais.

**Genérico de propósito.** Nada no código fala de um ramo. O que muda de um negócio para outro (os tipos, os prazos, os campos de cada tipo, se a IA abre o caso) é **configuração da conta**. A conta nasce com um modelo neutro no idioma dela, como os funis.

Flag por conta: **`cases`**, no fim de `feature_flags_ext_1` (depois de `commerce`). Menu **CRM**.

## Referência: o Casos do DeskComm

No DeskComm (`/Volumes/KINGSTON/projetos_ia/crm`, spec `docs/specs/15-spec-casos-humanos.md`), o caso é só o **laço IA → equipe**. A IA trava e abre o caso, mas continua falando com o cliente. A equipe responde à IA, e a IA repassa ao cliente. Os limites dele:

- não tem caso manual;
- não tem responsável, prioridade, prazo nem número legível;
- não tem campos próprios nem ligação com negócio;
- os tipos são fixos no código e vieram de um cliente tipo clínica;
- o prazo de 24 h e o limite de 3 lembretes estão escritos no código;
- o aviso de caso aberto vai só pelo WhatsApp de um número da equipe.

Aproveitamos a ideia do laço (fase 2) e o histórico só de acréscimo (*append-only*). O resto é novo.

## Decisões do Paulo (09/10/2026)

- **O que a IA faz ao travar é configurável por tipo:** abrir o caso e **continuar atendendo** (a equipe responde no caso e a IA repassa) ou abrir o caso e **passar a conversa** para a equipe, como a passagem de hoje.
- **O cliente recebe avisos pela conversa:** o número do caso ao abrir e um aviso ao resolver. Liga e desliga por tipo. Não há página pública.
- **Campos próprios por tipo** entram na fase 1.

## Fases

| Fase | O quê | Versão |
|---|---|---|
| 1 | Tipos (com campos próprios e prazo), casos, histórico, telas, abrir pela conversa e pelo contato, atrasados no menu e no Radar | 1.22.0 |
| 2 | A IA abre o caso (Jev decide antes do LLM, como agenda e catálogo) e repassa a resposta da equipe | 1.23.0 |
| 3 | Avisos ao cliente pela conversa e métricas (tempo até resolver, atrasos por tipo e por responsável) | 1.23.0 |

## Dados

Os models ficam em `app/models/cases/`, e o prefixo das tabelas é `cases_`.

| Tabela | Para quê |
|---|---|
| `cases_types` | Tipo de caso da conta: `name`, `color`, `position`, `active`, `sla_hours` (prazo; nulo = sem prazo), `default_priority`, `default_assignee_id`/`default_team_id`, `fields` (jsonb, os campos próprios), `ai_mode` (`off`, `continue`, `handoff`), `ai_instructions` (quando a IA deve abrir este tipo, em texto livre, vai para o Jev), `notify_customer` |
| `cases_cases` | O caso: `number`/`year`/`sequence` (`CAS-2026-0001`, como os documentos), `title`, `description`, `type_id`, `status`, `priority`, `assignee_id`, `team_id`, `due_at`, `contact_id` (obrigatório), `deal_id`, `source` (`manual`, `conversation`, `ai`), `field_values` (jsonb), `outcome` e `resolution` (ao resolver), `resolved_at`/`resolved_by`, `canceled_at`, `created_by` |
| `cases_conversations` | Ligação do caso com as conversas (uma ou mais; a conversa de onde o caso nasceu fica marcada como `origin`) |
| `cases_events` | Histórico só de acréscimo: `kind` (`created`, `status_changed`, `assigned`, `priority_changed`, `due_changed`, `field_changed`, `note`, `conversation_linked`, `ai_note`, `customer_notified`), `actor_kind` (`user`, `ai`, `system`), `actor_id`, `body`, `metadata` |

O prefixo do número fica em `accounts.settings` (`cases_prefix`, `store_accessor` no `CortexgenAccount`; vazio = `CAS`), sem tabela própria. A API é `GET/PATCH cases/settings`.

**Situação (`status`):** `open` → `in_progress` → `waiting_customer` → `resolved` / `canceled`. `waiting_customer` **pausa o prazo**: ao voltar, `due_at` anda o tempo que ficou parado.

**Desfecho (`outcome`), ao resolver:** `solved`, `not_applicable`, `duplicate`, `no_response`. É genérico. O texto livre fica em `resolution`.

**Prioridade:** `low`, `normal`, `high`, `urgent`.

**Prazo:** `due_at = created_at + sla_hours`, em horas corridas na fase 1. Horário comercial pode vir depois, com a jornada do Agenda (`Agenda::Availability`) ou o horário da caixa. Mudar o prazo à mão fica no histórico.

### Campos próprios

`cases_types.fields` é uma lista com `key`, `label`, `type` (`text`, `number`, `date`, `select`, `boolean`), `options` (para `select`) e `required`. Os valores ficam em `cases_cases.field_values` com a `key`. Validação no model:

- tipo do valor;
- obrigatório ao **resolver**: abrir não exige, porque a IA abre com pouco dado.

A `key` não muda depois de criada. Renomear muda só o `label`. Apagar um campo deixa o valor antigo no caso, como histórico, e a tela não o mostra mais.

### Modelo padrão

O modelo padrão nasce no idioma da conta (pt/es/en), sem campos e sem IA. O admin liga a IA e acrescenta campos em cada tipo.

| Tipo | Prazo | Prioridade |
|---|---|---|
| Dúvida | 24 h | normal |
| Problema | 8 h | alta |
| Solicitação | 48 h | normal |
| Reclamação | 4 h | alta |
| Financeiro | 24 h | normal |

## Fase 1 — o módulo

- **API** `/api/v1/accounts/:id/cases/...`:
  - `types` (CRUD; tipo com caso não se apaga, desativa);
  - `cases` (lista com filtros, CRUD, ações `start`, `wait_customer`, `resolve`, `cancel`, `reopen`, `link_conversation`);
  - `events` (lista e `note`);
  - `cases/overdue_count`.

  Política: agente vê e trabalha nos casos; admin configura tipos.
- **Serviço** `Cases::CaseFlow`: muda a situação, grava o evento e recalcula o prazo. A nota com menção usa o `Messages::MentionService` (ou `Commerce::TeamNote`, se ficar genérico). Atribuir notifica o responsável. Ver o que o `NotificationBuilder` do Chatwoot aceita: se não houver tipo de notificação adequado, usar a menção numa nota da conversa de origem.
- **Telas:**
  - `/cases`: lista e quadro por situação. Filtros: tipo, situação, responsável, prioridade, atrasados e "meus". Busca por número, título e contato (sem acento, como o `Commerce::Search`).
  - `/cases/:id`: cabeçalho (número, tipo, situação, prioridade, responsável, prazo), descrição, campos do tipo, contato, negócio, conversas ligadas, histórico com notas, ações.
  - **Abrir caso** pelo painel da conversa: um bloco **Cases** no `ContactPanel`, com os casos abertos do contato e o botão. O caso nasce ligado à conversa, com o contato e o negócio aberto. Também pela aba **Cases** do contato.
  - **Configuração:** Settings → Cases → Tipos (lista, editor com os campos próprios, prazo, padrões, IA e aviso ao cliente) e o prefixo.
- **Avisos à equipe:**
  - **Número vermelho** de atrasados no item Cases do menu, com o mesmo mecanismo do `review_count` dos documentos (store relido a cada minuto, `countClass`).
  - Casos vencidos entram no **Radar** como risco.
- **Excluir contato** apaga os casos dele, como os negócios e as tarefas. **Juntar contatos** leva os casos (`CortexgenContactMerge`).
- **Smoke** `cases` no `ops/smoke/run.sh`.

## Fase 2 — a IA abre o caso e repassa

Segue a lição da agenda e do catálogo: **a ação é decidida pelo Jev antes do LLM, não por etiqueta** (memória `bot-acao-pelo-jev-antes-do-llm`).

- **Abrir:**
  - No `MontaPrompt`, com a atividade `case` do Jev decidindo, uma `choice` entre os tipos com `ai_mode != off` (+ `none`). O critério de cada tipo vem de `ai_instructions`.
  - Acima do limiar, `POST /cases/bot/cases` cria o caso com título e resumo. O resumo vem da conversa, como o briefing da passagem, e tem dois campos: "o que o cliente precisa" e "por que a IA não resolve".
  - O caso já leva os campos próprios que o Jev conseguir extrair da conversa.
- **Depois de abrir:**
  - `continue`: o prompt diz à IA que a equipe está vendo e dá o número. A IA segue atendendo o resto, e o caso fica `open` com o responsável notificado.
  - `handoff`: abre o caso e faz a passagem de hoje, com o briefing e o número do caso.
- **Repassar (`continue`):**
  - Na tela do caso, a equipe escreve a resposta em **"Responder pelo assistente"**. O Rails chama um webhook do n8n (workflow novo **CortexGen Caso**, ou um ramo do bot), e a persona escreve a mensagem no idioma do cliente, com o texto da equipe como fonte.
  - Também há **"Pedir dado ao cliente"**: a IA pergunta, o caso vai para `waiting_customer`, e a resposta do cliente volta para o caso como evento (o Jev reconhece no turno seguinte).
- **Rede de segurança:** no `JevRevisao`, a promessa de "vou verificar com a equipe" sem caso aberto vira o caso, ou retém a mensagem, como o `false_booking`/`false_sale`.
- A IA não abre caso duplicado: se o contato já tem um caso aberto do mesmo tipo, acrescenta uma nota a ele.

## Fase 3 — avisos ao cliente e métricas

- **Aviso ao cliente** (tipos com `notify_customer`):
  - ao abrir, uma mensagem na conversa de origem com o número e o prazo em linguagem simples;
  - ao resolver, uma mensagem com o desfecho.

  Os textos ficam em es/pt/en no idioma do contato, fora do i18n da interface, como o `DocumentLabels`. Pelo WhatsApp oficial, fora da janela de 24 h, só com template, o que ainda não temos: nesse caso o aviso não sai, e o histórico registra.
- **Métricas:** casos abertos e resolvidos no período, tempo médio até resolver, atrasados por tipo e por responsável, e casos abertos pela IA.

## Como ficou a fase 1 (1.22.0)

- **Código:** models em `app/models/cases/`; `Cases::CaseFlow` (`app/services/cases/case_flow.rb`) abre, edita, muda a situação, anota e liga conversas, sempre gravando o evento; controllers em `app/controllers/api/v1/accounts/cases/`; telas em `app/javascript/dashboard/routes/dashboard/cases/`.
- **Rotas:** `GET/POST cases`, `GET/PATCH/DELETE cases/:id`, `POST cases/:id/{start,wait_customer,resolve,cancel,reopen,note,link_conversation}`, `GET cases/overdue_count`, `cases/types` e `cases/settings`. O `namespace :cases` vem antes do `resources :cases` nas rotas, para `/cases/types` não cair no `show`.
- **Notificação:** atribuir a outra pessoa posta uma nota privada com menção na conversa de origem (ou a mais recente ligada), como o `Commerce::TeamNote`. Caso sem conversa não notifica: aparece em "Mine" e no número vermelho.
- **Ao abrir pela conversa,** o histórico tem só "created" (com o número da conversa); "conversation_linked" fica para as conversas ligadas depois.
- **Transição proibida** ou obrigatório faltando ao resolver levantam `RecordInvalid` (422), como o `DocumentFlow`.
- **Tela:** o bloco Cases do painel da conversa entrou no `DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER` (`useUISettings.js`) e só aparece com a flag; a aba Cases do contato também. O Radar ganhou a seção de casos vencidos (`Sales::Radar#overdue_cases`, vazia sem a flag).
- **Fora da fase 1, de propósito:** `ai_mode`, `ai_instructions` e `notify_customer` já existem no tipo, mas o editor não os mostra até as fases 2 e 3 funcionarem.
- **Teste:** `ops/smoke/cases.rb` (61 cenários) no `ops/smoke/run.sh`.

## Como ficaram as fases 2 e 3 (1.23.0)

**Fluxo no bot** (`pd5V9pdaldRLUu4C`, patch `ops/n8n/patch_casos.py`):
- `Guard`: atividade `case` do Jev, decidindo por padrão (o `JevController` tem a mesma tabela; cartão "Open cases for the team").
- `JevEntrada`: pergunta `case` (noul ≥ 0,6), na mesma chamada das outras.
- `MontaPrompt` lê `GET cases/bot/context` em toda mensagem (401 = conta sem a flag, segue sem casos):
  - caso esperando resposta do cliente: a mensagem vai para `POST cases/bot/customer_replies`;
  - com o Jev vendo um caso, um `choice` entre os tipos com IA (critério = nome + "Quando é este tipo?", confiança ≥ 0,8) e `POST cases/bot/cases` antes do LLM. O título é a primeira frase do cliente; a descrição, a fala inteira;
  - a seção `# CASES` (antes da memória e do idioma) dá o número, pede para seguir atendendo ou avisa que a equipe assume, lista os casos ativos com a situação em palavras e proíbe número inventado.
  - Saídas `caseTypes`, `caseOpened`, `caseHandoff`, `caseReplied`.
- `JevRevisao`: rede `false_case` (≥ 0,7) quando há tipos com IA e nenhum caso neste turno: resposta que promete retorno da equipe vai para a `Passagem`.
- `PrecisaHandoff` (agora no repo, `precisa_handoff.js`): tipo `handoff` passa a conversa depois da resposta, motivo `case` na nota.
- **Medido no Jev real em 12/10:** `case` 0,87–0,95 nos positivos (es/pt/en) e 0,03–0,33 nos negativos (preço, horário, agendar, cotação, saudação); tipo com confiança 1,00 em 5 de 5; `false_case` 0,98–0,99 nas promessas e 0,01–0,04 nas respostas próprias.

**Repasse da equipe:** `Cases::CaseFlow#relay!` grava o evento `team_reply` (`mode` answer/ask, `relay` pending). O workflow **CortexGen Caso** (`ops/n8n/build_caso.py`, id `v8JhnhlKRAoBmFxt`, a cada minuto) faz Candidatos → MontaRepasse → LLM da persona → EnviaRepasse:
- reserva com `POST cases/bot/relays/claims`, só das conversas nas caixas com bot; a reserva vence em 10 min;
- a persona reescreve no idioma e no tom, sem acrescentar fato;
- posta como o bot, com bolhas e "digitando" no OpenWA, e devolve o resultado com `POST cases/bot/relays/:id`;
- se o LLM falhar, vai o texto da equipe; no teto de IA, também vai o texto da equipe, sem LLM;
- falha ao postar avisa quem escreveu;
- pergunta enviada põe o caso em `waiting_customer`; a resposta do cliente (`customer_replied`) volta o caso para `in_progress` e menciona o responsável;
- conversa numa caixa sem bot: o repasse fica pendente (a tela mostra "waiting to be sent").

**Avisos ao cliente:** `Cases::CustomerNotice` (textos em `Cases::CustomerLabels`, es/pt/en). O idioma vem do que a IA viu ao abrir, da conversa ou da conta. Caso aberto pela IA não recebe o aviso de abertura.

**Métricas:** `Cases::Metrics`, `GET cases/metrics?days=` (7 a 365), tela `/cases/metrics`.

**Testes:** smoke `cases_ai` (32), `node ops/n8n/test/casos.test.js` (28).

**Pendente, se fizer falta:** a IA preencher campos próprios do tipo (os de lista e sim/não dariam `choice`/`noul` do Jev); contar o prazo só no horário comercial.
