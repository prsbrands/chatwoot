# Campanhas por QR — proposta de desenho

**Estado: aprovada em 19/10 e no ar desde a 1.25.0 (1.25.1 com a correção da tela). Provada em uso só até o "Send test"; o que a implementação mudou está em "Mudanças na implementação" no fim. Manual de uso: `docs/manual/outreach.{en,es,pt}.md`.**

Disparo de mensagens do WhatsApp por QR (OpenWA) para uma lista de pessoas, com proteção contra banimento. É o último módulo do DeskComm sem equivalente aqui (`/Volumes/KINGSTON/projetos_ia/crm`, `lib/campanhas/`).

Flag por conta: **`outreach`**, no fim de `feature_flags_ext_1` (depois de `ai_evolution`). Menu **CRM**.

## O que existe hoje

- O Chatwoot tem campanhas de Website, Twilio SMS, SMS e WhatsApp oficial (só com template aprovado, que o Paulo não tem). **O canal API, que é onde o WhatsApp por QR vive, não tem campanha nenhuma.**
- O anti-ban já existe no follow-up (n8n, `followup_candidatos.js`): janela de 8h às 20h no fuso da inbox, teto diário pela idade do número (20 / 50 / 100 / 200), 20 a 45 s entre envios, veto por texto parecido (Jaccard ≥ 0,8 com 2 dos últimos 20 envios do número).
- A resposta do cliente a uma mensagem enviada pelo QR já cai no bot da caixa, e o `OptOut` do bot já bloqueia o contato (`blocked`) quando ele pede para parar.
- O envio pelo QR vindo do Rails já existe: `Agenda::CustomerMessage` cria uma mensagem de saída, sem remetente, na conversa do contato num número QR (inbox `Channel::Api` com `webhook_url` do `/chatwoot-adapter/`).
- A conta 1 tem um número QR só (inbox 33). Rodízio entre vários números **fica de fora**.

## O que o DeskComm faz e aproveitamos

| DeskComm | Aqui |
|---|---|
| Ritmo próprio da campanha por cima do ritmo do canal, sempre o mais restritivo (`ritmo.ts`) | Igual: a campanha só sabe ir mais devagar que o número |
| Vetos como função pura, rodados na preparação **e de novo antes de cada envio** (`elegibilidade.ts`) | Igual, em `Outreach::Eligibility` |
| Espera por ritmo não é falha: o destinatário continua pendente | Igual |
| Estados da campanha com máquina de transição única (`maquina-de-estados.ts`) | Igual, em `Outreach::Campaign` |
| Funil por carimbo (enviada, entregue, lida, respondida) e atribuição de resposta em 72 h | Igual; a janela é configurável |
| Lista de exclusão da operação, separada do opt-out (`exclusoes.ts`) | Igual |
| Rodízio entre números, base legal LIA, busca de empresas no Apify | **Fora desta versão** |

## Decisões do Paulo

- **Escopo:** só Campanhas por QR. A busca de empresas (Prospecção/Apify) fica para depois.
- **Audiência:** contatos do CRM **e lista importada, inclusive fria** (quem nunca falou com a empresa).
- **Importação:** CSV, XLS e XLSX, e o que mais couber (ODS).
- **Mensagem:** texto com variáveis e até 3 variações; o sistema alterna. A resposta do cliente cai no bot da caixa.
- **Humanização e anti-banimento no código:** envios por período, bolhas e atraso entre mensagens, configuráveis.
- **Um teto só por número:** campanha e follow-up somam no mesmo teto diário.

## A mensagem

- Texto com variáveis `{name}` (primeiro nome), `{full_name}`, `{company}` e as colunas da lista importada (`{coluna}`). Variável que falta num destinatário o tira da lista com o motivo `missing_variable`, como no DeskComm.
- **Variações:** de 1 a 3 textos. O sistema alterna entre elas pelo destinatário. Dentro do texto, `{Oi|Olá|Hola}` escolhe uma opção por envio.
- **Bolhas:** uma linha em branco separa as bolhas (até 4), com a mesma regra do bot (`bolhas()` em `responde.js`: lista e frase com `:` colam na anterior).
- **Digitando:** antes de cada bolha, `toggle_typing_status` e uma espera proporcional ao tamanho (a mesma conta do `atraso()` do bot), com variação aleatória.
- **Rodapé de saída:** opção ligada por padrão em lista fria, "Responda PARAR para não receber mais". Quem responde cai no `OptOut` que já existe e vira `blocked`.
- **Enviar teste para mim:** antes de iniciar, manda a mensagem renderizada para um número da equipe, sem entrar nas métricas.

## Proteção do número (o coração do módulo)

Configuração por campanha, com padrões da conta. **A campanha só pode ser mais lenta que o número, nunca mais rápida.**

| Controle | Padrão | Observação |
|---|---|---|
| Janela de horário | 8h às 20h no fuso da inbox | Dias da semana configuráveis. Inbox em UTC não dispara, como no follow-up |
| Intervalo entre envios | aleatório de 20 a 45 s | Piso de 15 s, que a tela não deixa baixar |
| Máximo por hora | 30 | Configurável para baixo |
| Máximo por dia | o menor entre o da campanha e o do número (idade: 20 / 50 / 100 / 200) | Número em warm-up manda menos |
| **Lote e pausa** | 10 envios, depois pausa aleatória de 5 a 15 min | "Número de envios por período": o ritmo de uma pessoa, não de um robô |
| **Lista fria** | metade do teto do dia | Quem nunca falou com a empresa é o padrão que o WhatsApp bane |
| Texto parecido | veta Jaccard ≥ 0,8 com 2 dos últimos 20 envios do número | Mesma regra do follow-up. Com 3 vetos, a campanha pausa |
| Variações e opções `{a|b}` | alternam | Reduz o texto repetido |

**Pausa automática**, com aviso na campanha e nota para a equipe:
- sessão do número saiu de `ready` (o `SessionWatchJob` já marca a inbox) ou 3 falhas de envio seguidas;
- 5 ou mais pedidos de parada nos últimos 30 envios;
- 30% ou mais dos últimos 20 destinatários sem entrega (número que não existe ou não tem WhatsApp).

**Verificar o número antes de enviar** (sinal forte de risco: mandar para quem não tem WhatsApp). **Ponto em aberto:** o adaptador do OpenWA precisa ter um endpoint para isso. Se não tiver, a proteção fica só na pausa por falta de entrega.

## Quem pode receber (vetos)

A mesma função roda na preparação e **imediatamente antes de cada envio**, porque entre as duas a pessoa pode ter pedido para parar.

| Motivo | Regra |
|---|---|
| `opt_out` | Contato `blocked` |
| `no_phone` / `invalid_phone` | Sem telefone, ou fora do E.164 depois de normalizar |
| `suppressed` | Está na lista de exclusão da operação (decisão de quem opera, não silencia o atendimento) |
| `duplicate` | Mesmo telefone já na lista; vale o primeiro |
| `in_other_campaign` | Já em outra campanha ainda não concluída |
| `recently_contacted` | Recebeu campanha deste número nos últimos 30 dias (configurável) |
| `active_conversation` | Conversa aberta com uma pessoa da equipe: a campanha não interrompe atendimento |
| `missing_variable` | Falta um dado que a mensagem usa |
| `manual` | Retirado à mão da campanha |

A tela mostra a contagem por motivo **antes** de iniciar. Iniciar exige confirmação.

## Importação de lista

- Formatos: **CSV, XLS, XLSX e ODS**. O Rails lê com a gem `roo` (MIT; XLS por `roo-xls`, também MIT), porque o projeto é só MIT e não tem biblioteca de planilha no front.
- Fluxo em três passos, como o assistente de importação de contatos:
  1. enviar o arquivo (limite de 10 mil linhas e 5 MB);
  2. **mapear as colunas** (telefone obrigatório; nome, empresa e as demais viram variáveis), com as 5 primeiras linhas de prévia;
  3. revisão: quantas linhas entram e quantas saem, por motivo, com a lista das que saem para baixar.
- **O telefone é normalizado para E.164** com o código de país padrão da conta (Panamá, +507) quando falta. Número sem código e fora do padrão vira `invalid_phone`.
- **Quem nunca foi enviado não vira contato.** A linha fica na campanha (`outreach_recipients`); o contato é achado ou criado **no momento do envio**. Assim, uma lista fria de 5 mil números não polui o CRM com gente que a campanha nunca tocou.

## Audiência a partir do CRM

Filtro por **etiqueta**, **etapa do funil** e **inbox**, com prévia. É a mesma lista de vetos, então quem está bloqueado ou sem telefone sai com o motivo.

## Dados

Models em `app/models/outreach/`, tabelas com prefixo `outreach_`, sem chave estrangeira no banco (regra do projeto).

| Tabela | Para quê |
|---|---|
| `outreach_campaigns` | `account_id`, `inbox_id` (número QR), `name`, `status` (`draft`, `preparing`, `ready`, `running`, `paused`, `completed`, `cancelled`, `failed`), `variants` (jsonb, até 3 textos), `cold` (bool), `opt_out_footer`, `pacing` (jsonb com janela, dias, intervalo mín./máx., teto hora/dia, lote e pausa), `audience` (jsonb: origem `crm` ou `import`, filtros), `attribution_hours`, `started_at`, `paused_at`, `paused_reason`, `completed_at`, `created_by` |
| `outreach_recipients` | `campaign_id`, `phone` (E.164), `name`, `variables` (jsonb, as colunas da lista), `contact_id` (nulo até o envio), `conversation_id`, `message_id`, `variant` (índice), `status` (`pending`, `excluded`, `sending`, `sent`, `delivered`, `read`, `replied`, `failed`, `opted_out`, `cancelled`), `excluded_reason`, `error`, `next_attempt_at`, carimbos `sent_at`, `delivered_at`, `read_at`, `replied_at`. Índice único `(campaign_id, phone)` |
| `outreach_suppressions` | Lista de exclusão da operação: `account_id`, `phone`, `reason`, `created_by`. Único por `(account_id, phone)` |
| `outreach_imports` | Arquivo enviado e mapeamento de colunas, para reprocessar sem reenviar: `campaign_id`, `file` (ActiveStorage), `mapping`, `stats` |

O último envio de qualquer origem num número (para o intervalo e para o veto de texto parecido) é lido das mensagens de saída da inbox, sem tabela própria.

## Execução

- **Rails, não n8n.** A fila precisa de intervalos de 20 a 45 s e de decisão a cada envio; o n8n a cada 15 min não serve, e o envio já mora no Rails (`Agenda::CustomerMessage`).
- `Outreach::SendNextJob` (Sidekiq): trava a campanha, confere `running`, janela, teto e intervalo, pega o próximo `pending`, **revalida os vetos**, acha ou cria o contato e a conversa na inbox QR, manda as bolhas com "digitando" e agenda a si mesmo com o próximo intervalo aleatório.
- O `TriggerScheduledItemsJob` (a cada 5 min) religa a cadeia de campanha `running` que morreu e aplica as pausas automáticas.
- Ritmo é espera, não falha: fora da janela ou no teto, o destinatário continua `pending` e o job reagenda para a abertura da janela.
- **Conversa criada pela campanha nasce `pending`, sem atribuição**, para o bot da caixa atender a resposta. A mensagem enviada vai como saída sem remetente (resposta de agente tiraria a conversa do bot).
- Os carimbos `delivered` e `read` vêm dos status que o adaptador já devolve ao Chatwoot. **Ponto a confirmar:** que o OpenWA os devolve para mensagens criadas pelo Rails.
- Resposta: o `CortexgenMessage` (que já trata mensagem de entrada) carimba `replied_at` no destinatário mais recente dentro da janela de atribuição, e `opted_out` se o contato virou `blocked`.

## Teto único com o follow-up

- O follow-up soma seus envios em `bot_followup_sends` (Supabase). Os da campanha ficam no Rails.
- `Outreach::NumberBudget` calcula a folga do número no dia: teto pela idade (`number_activated_at`) menos os envios de campanha de hoje **menos os do follow-up**, lidos pelo `Integrations::Botlayer::Client`.
- O `Candidatos` do follow-up passa a perguntar a folga ao Rails (rota `outreach/bot/capacity`, `chat_user_token`) e subtrai o que a campanha já mandou. Isso muda o workflow do follow-up (patch n8n), por isso vai na **segunda entrega**.

## Telas

- **Campaigns** (menu CRM, junto da lista de campanhas existente; **nome a decidir**, para não confundir com as do Chatwoot):
  - **Lista:** nome, número, estado, enviados, respostas, andamento.
  - **Assistente de criação:** 1. audiência (CRM ou arquivo, com mapeamento e prévia); 2. mensagem (variações, bolhas, prévia com um contato de exemplo, enviar teste); 3. ritmo (padrões já preenchidos, com o teto efetivo do número em destaque); 4. revisão (contagem por motivo de exclusão) e **Iniciar**.
  - **Detalhe:** funil enviada → entregue → lida → respondida, com as taxas separadas, a fila (quem sai agora e quando), os excluídos com o motivo e **Pausar / Retomar / Cancelar**.
- **Exclusões:** lista de números que a operação não quer em campanha (adicionar, importar, remover).
- Número vermelho no menu quando uma campanha foi pausada automaticamente.
- Textos só em `en.json`; os demais idiomas vêm pelo Crowdin.

## Entregas

1. **1.25.0:** campanha por QR de ponta a ponta, com audiência do CRM **e importação (CSV, XLS, XLSX)**, mensagem com variações e bolhas, ritmo (janela, intervalo aleatório, teto hora/dia, lote e pausa, metade do teto em lista fria), vetos, lista de exclusão, funil e pausa por sessão caída e por falhas.
2. **1.25.1:** teto único com o follow-up (patch do workflow), pausa por pedidos de parada e por falta de entrega, rodapé de saída e veto de texto parecido.

## Testes

- Smoke `outreach`: vetos (cada motivo), revalidação antes do envio, ritmo (janela, teto, intervalo, lote), pausa automática, importação (CSV, XLSX e XLS, colunas, E.164, duplicados, injeção), atribuição de resposta e flag. O OpenWA entra falso, como nos outros smokes.
- **Teste real:** uma campanha para 3 números do Paulo na inbox 33 (que já está além dos 14 dias, teto de 200), com a janela aberta e o intervalo curto só no teste.
- Conta de demonstração com uma lista sintética, sem tocar a conta 1.

## Fora desta versão

- Rodízio entre vários números.
- Busca de empresas (Prospecção/Apify).
- Campanha pelo WhatsApp oficial (precisa de template aprovado no Meta) e por SMS: as do Chatwoot continuam valendo.
- Sequência de insistência para quem não respondeu.
- A IA escrever o texto por contato.

## Mudanças na implementação (1.25.0)

O que a leitura do adaptador do OpenWA e o código mostraram, e que muda o desenho acima:

- **O envio é direto pelo gateway** (`POST /sessions/:id/messages/send-text`), não por mensagem do Chatwoot. O adaptador só leva ao WhatsApp a mensagem de uma conversa que o cliente já abriu (mapa conversa → chat, criado quando o cliente escreve), e descarta o resto. Por isso não há contato nem conversa até a pessoa responder; o histórico entra quando ela escreve, pela importação de histórico do adaptador. O gateway já simula o "digitando" antes de cada texto.
- **Sem "entregue" e "lida".** O adaptador não devolve o status de entrega de uma mensagem que ele não mapeou, então o funil é enviada, respondida, parou, falhou. A pausa por "30% sem entrega" fica para quando houver como medir.
- **XLS antigo fica de fora.** Lê CSV, XLSX e ODS (gem `roo`, MIT). O XLS precisa de uma biblioteca GPL (`spreadsheet`), contra a decisão de só MIT. Salvar como XLSX resolve.
- **Sem a verificação "o número tem WhatsApp".** O gateway não expõe esse endpoint na documentação pública; fica como ponto em aberto.
- **Estados:** `draft`, `ready`, `running`, `paused`, `completed`, `cancelled` (sem `preparing` e `failed`: a preparação é síncrona, e falha de envio é da pessoa, não da campanha).
- **Rodapé de saída** é um texto livre da campanha (opcional), e não um liga/desliga: o idioma é de quem escreve.
- **Já na 1.25.0**, além do combinado: rodapé de saída e o teto do dia pela idade do número (com metade para lista fria).
- **Fica para a 1.25.1:** teto único com o follow-up, pausa por pedidos de parar, veto por texto parecido.
- **Uma tela só por campanha:** a página da campanha reúne mensagem, ritmo, lista, revisão e resultados, em vez de um assistente em passos; criar pede só nome, número e a primeira mensagem.
- **Etapa do funil como filtro:** a API aceita `stage_id`, mas a tela filtra só por etiqueta e caixa.
- **Habilitar no OpenWA:** `SEND_PACING_ENABLED=true` liga o teto por idade da sessão e um teto separado para conversas novas no próprio gateway, que fica como segunda camada por baixo da campanha.
