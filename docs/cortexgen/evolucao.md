# Evolução da IA — desenho

A IA aprende com o que a equipe faz quando ela não dá conta. Uma vez por dia, uma rodada lê as conversas em que a IA passou o cliente para uma pessoa, teve a resposta retida pelo Jev ou abriu um caso, e propõe mudanças concretas: um trecho novo para a base de conhecimento, a correção de um trecho existente ou uma regra nova para o prompt da persona. Cada proposta mostra a evidência (o que o cliente perguntou e o que a equipe respondeu). Nada muda sem aprovação: na tela **AI evolution**, a equipe revisa, edita, aplica ou recusa.

**Genérico de propósito.** Nada no código fala de um ramo de negócio. O que a IA aprende vem das conversas e da base de cada conta.

Flag por conta: **`ai_evolution`**, no fim de `feature_flags_ext_1` (depois de `cases`). Menu **AI**.

## Referência: a "Evolução da IA" do DeskComm

No DeskComm (`/Volumes/KINGSTON/projetos_ia/crm`), `/app/ai/evolution` é **só um painel de números**: buscas sem resultado, quase acertos, passagens, custo. Ele não mostra quais perguntas falharam, porque não guarda o texto.

As propostas vêm de outro módulo, o *flywheel* (`lib/agent-engine/flywheel/live.ts`). É um juiz LLM que roda a cada 6 h e avalia uma única dimensão: se a IA guardou os fatos do cliente. Quando a resposta é "não", ele propõe uma linha para o prompt ou para a memória da organização. As limitações:
- não dá para editar a proposta antes de aplicar, nem recusar;
- o juiz reavalia as mesmas conversas a cada rodada (custo sem nada novo);
- os prompts do juiz falam de "agente SDR de lojas", em português.

Aproveitamos a ideia do portão humano e da evidência ligada à conversa. A fonte de aprendizado é outra: **o que a equipe respondeu quando a IA não deu conta**.

## Decisões do Paulo (12/10/2026)

- **Propostas:** trecho novo na base, correção de trecho da base e regra nova no prompt da persona.
- **Sempre com aprovação:** a equipe pode editar o texto antes de aplicar, ou recusar com motivo.
- **Uma rodada por dia**, só com conversas novas que tenham sinal, com teto por conta. Entra no Uso de IA e no teto mensal.
- **Teste numa conta de demonstração** com conversas sintéticas, sem misturar com a conta 1. Não há dados reais até a liberação final.

## Os sinais

Uma conversa entra na rodada quando tem, desde a última leitura, pelo menos um destes sinais. Todos já existem: não é preciso instrumentar nada novo.

| Sinal | Como se reconhece | O que ensina |
|---|---|---|
| **Passagem com resposta da equipe** | Nota privada da `Passagem` (o bot passou a conversa) e, depois dela, mensagem pública de uma pessoa da equipe | A resposta que a IA não sabia dar: candidata a trecho da base ou a regra |
| **Resposta retida pelo Jev** | Nota da `Passagem` com motivo `reply_review` e o rascunho retido | O que a IA ia dizer de errado e o que a equipe mandou no lugar |
| **Caso aberto pela IA** | `Cases::Case` com `source: ai` ligado à conversa | O que a IA não resolve sozinha; às vezes há uma resposta que a base poderia ter |

A rodada lê a conversa da última leitura até agora. O mesmo trecho nunca é pago duas vezes: o Rails guarda até onde leu, como a Memória da IA.

## Dados

Os models ficam em `app/models/ai_evolution/`, e o prefixo das tabelas é `ai_evolution_`.

| Tabela | Para quê |
|---|---|
| `ai_evolution_scans` | Uma linha por conversa lida: `conversation_id`, `last_message_id` (até onde leu), `claimed_at` (reserva de 1 h), `scanned_at`, `signals` (jsonb) |
| `ai_evolution_suggestions` | A proposta. Campos: `kind` (`knowledge_add`, `knowledge_update`, `prompt_rule`), `status` (`pending`, `applied`, `rejected`), `persona_id` e `persona_name` (a persona da caixa), `title`, `content` (o texto proposto), `target_doc_id` e `target_doc_title` (a correção, ou o documento onde entra o trecho novo), `replace_text` (o trecho que a correção troca, copiado da base), `rationale`, `evidence` (jsonb, lista de `{conversation_id, signal, customer_quote, team_quote, at}`), `evidence_count`, `edited`, `previous_content` (para desfazer), `applied_at`/`applied_by`, `rejected_at`/`rejected_by`/`reject_reason` |

**Duplicadas:** a rodada recebe os títulos das propostas pendentes da mesma persona. Quando a conversa ensina a mesma coisa, o LLM devolve `same_as: <id>`, e a evidência entra na proposta existente, que sobe na lista por `evidence_count`. Assim, cinco clientes perguntando o prazo de entrega viram uma proposta com cinco evidências, não cinco propostas.

**Recusadas:** a rodada também recebe os títulos recusados nos últimos 90 dias (com o motivo), para não propor de novo o que a equipe já disse que não quer.

## A rodada (workflow "CortexGen Evolução", n8n)

`ops/n8n/build_evolucao.py`, como o da Memória. Todo dia às 3h do fuso da conta, com teto de 20 conversas por conta.

1. **Candidatos:** `POST ai_evolution/bot/claims` com as caixas do bot de cada conta. O Rails reserva as conversas com sinal novo e devolve para cada uma:
   - o trecho da conversa e os sinais;
   - a persona (nome e o começo do prompt);
   - os títulos das seções da base dessa persona, com o id do documento;
   - as propostas pendentes e as recusadas.

   Conta no teto de IA fica de fora.
2. **MontaEvolucao:** monta o prompt para o modelo da persona (o normal, não o leve: aqui a qualidade importa mais que o custo). Pede só JSON: `{ suggestions: [{ kind, title, content, target_doc_id, replace_text, same_as, rationale, customer_quote, team_quote }] }`. Lista vazia é a resposta comum. As regras:
   - propor só o que a **equipe** disse ou fez: nunca inventar política, preço ou prazo;
   - não propor o que a base já diz;
   - trecho curto e factual, no idioma da base;
   - correção só copiando o trecho exato a trocar (`replace_text`);
   - regra de prompt só para comportamento ("não prometa prazo de entrega"), não para fato;
   - os dados do cliente (e-mail, telefone, documento) saem do texto antes do LLM, como no Jev.
3. **LLM** da persona (o mesmo IF e os mesmos nós do bot, clonados).
4. **GravaEvolucao:**
   - registra o uso (`kind 'evolution'` em `bot_interactions`, com o SQL `db/botlayer/bot_ai_evolution.sql` acrescentando o valor à constraint, como a Memória fez);
   - grava pelo Rails, com `POST ai_evolution/bot/results`;
   - resposta ilegível não grava: a reserva vence e a conversa volta em outra rodada.

## Aplicar (Rails, pelo `Integrations::Botlayer::Client`)

- **`knowledge_add`:** acrescenta a seção `### <título>\n<texto>` ao documento escolhido.
  - Sem documento escolhido, vai para o documento **"Aprendizados da IA"** da conta, criado na primeira vez e ligado à persona da proposta.
  - O Jev já seleciona a base por seção (`###`), então o trecho novo entra no prompt só quando importa.
- **`knowledge_update`:** troca `replace_text` pelo texto novo no documento.
  - Se o trecho não estiver mais lá (alguém editou a base), a proposta não se aplica: a tela mostra o conflito e pede para ajustar à mão.
- **`prompt_rule`:** acrescenta a regra ao prompt da persona, numa seção `## Aprendizados` no fim (criada na primeira vez).
- **Antes de gravar,** o texto atual do documento ou do prompt fica guardado na proposta (`previous_content`), para **desfazer** a aplicação pela própria tela.

## Telas

- **AI evolution** (menu AI), em duas abas:
  - **Proposals:** as pendentes, das com mais evidência para as com menos, com filtro por tipo e por persona. Cada uma mostra o tipo, o título, o texto proposto (editável) e a diferença, no caso de correção. Mostra também o porquê e as evidências: frase do cliente, resposta da equipe e link para a conversa. Botões **Apply**, **Reject** (com motivo) e, nas aplicadas, **Undo**.
  - **Progress:** por semana, conversas atendidas pela IA, % passadas para a equipe, respostas retidas, casos abertos pela IA e propostas aplicadas, marcadas na linha do tempo. É o "antes e depois" que o DeskComm deixou de fora.
- **Número no menu:** propostas pendentes, como o número vermelho das cotizações.

## Conta de demonstração

`ops/demo/evolucao_seed.rb` monta a conta **"Demo Evolução"**. O Paulo roda; ele escreve no Supabase de produção. A conta tem:
- uma caixa de API;
- uma persona e uma base pequena (horário, preços, entrega);
- a rota do bot e o `chat_user_token`;
- umas 15 conversas sintéticas com os três sinais: perguntas que a base não cobre e que a equipe respondeu, uma resposta retida, um caso aberto pela IA, e repetições do mesmo assunto, para testar a junção de duplicadas.

A rodada roda sob demanda nessa conta, e a tela é conferida ali. Apagar a conta remove tudo.

## Testes

- Smoke `ai_evolution`: sinais, reserva, gravação com junção de duplicadas e recusadas, aplicar, conflito, desfazer, flag e permissões. O Supabase entra falso (`class_eval`), como o botlayer nos outros smokes.
- `node ops/n8n/test/evolucao.test.js`: os nós do workflow fora do n8n.

## Fora desta versão

- Aprender com edições que a equipe faça na resposta da IA (não temos modo rascunho).
- Avaliar se uma mudança aplicada melhorou: a aba Progress mostra a tendência, mas não atribui causa.
