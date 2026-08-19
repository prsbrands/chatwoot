# HANDOFF — CortexGen Chat

Última sessão: 2026-08-17 · Instância: https://prs.cortexgen.cloud

---

## ✅ O widget da conta 1 está ligado ao n8n — e toda resposta do bot deixava uma execução vermelha (17/08)

O snippet com `websiteToken: 'MrtKJhxPBc9DgjjCaU4so6o1'` é a **inbox 10 da conta 1** (hoje chamada `CortexGen Chat`). A cadeia inteira estava montada, mas nunca tinha sido exercitada depois da troca do Guard em 13/08 — a última conversa era de 08/08. Provado com mensagem real: o Nathan respondeu em ~2 s, e o Vitor (conta 2, inbox 21) também, pelo mesmo workflow.

| elo | estado |
|---|---|
| `AgentBotInbox` inbox 10 → Nathan | ativo, `outgoing_url` = `/webhook/cortexgen-bot` |
| rota no Supabase | ativa, persona `nathan-website`, 11.626 caracteres de prompt |
| secret e tokens por conta | gravados |
| pré-chat | ligado, com **nome, e-mail e telefone obrigatórios** |

**O defeito que o teste revelou:** desde 13/08, **toda** resposta do bot terminava numa execução vermelha `payload sem account/inbox`. O bot respondia normalmente — quem estourava era o evento seguinte. O Guard lia o inbox de `b.inbox.id`, que existe em `message_created`; em `conversation_updated` o corpo **é** a conversa e o campo mora na raiz (`b.inbox_id`). Das 17 execuções com erro desde 13/08, **15 eram esse falso alarme**, e as duas de verdade (`sem secret de bot`, `You are not authorized`) ficavam enterradas no meio.

**Isso é pior do que parece aqui**, porque a regra escrita neste handoff é "execução vermelha = alguém tem de olhar". Um evento que falha sempre transforma a lista em ruído e devolve exatamente o modo de falha que o Guard existe para evitar — o silêncio, agora por excesso de alarme em vez de falta.

Corrigido em `ops/n8n/guard.js` e no workflow ao vivo: `(b.inbox && b.inbox.id) || b.inbox_id || (b.conversation && b.conversation.inbox_id)`. Depois do patch, oito execuções seguidas verdes e resposta do bot nas duas contas.

**Como o patch foi aplicado, e por que não pelo MCP:** `update_workflow` apaga as credenciais dos nós HTTP — aqui levaria junto Supabase (`Persona`, `Log`) e OpenRouter (`LLM`). O caminho seguro é o que já estava escrito adiante: `n8n export:workflow` → editar o JSON → `n8n import:workflow` → publicar de novo (a importação **desativa** o workflow; o `publish_workflow` do MCP reativa). O script de patch só sobrescreve o nó Guard **se a única diferença com o repo for a linha esperada** — senão aborta, para não engolir em silêncio uma edição feita na tela. Conferido depois do import: credenciais de Supabase e OpenRouter intactas, `Historico`/`Responde`/`Handoff` ainda com header por expressão. Backup do export em `/tmp/wf-bot.json.bak-*` na VPS.

**Sobre captura de lead na conta 1:** quem captura é o **pré-chat obrigatório** — nome, e-mail e telefone viram contato antes da primeira mensagem. Não existe workflow de lead para o site da PRS (o `dagente-lead` é só da conta 2): o lead da conta 1 nasce e morre no Chatwoot, sem cópia em CRM externo. E o `enable_email_collect` da inbox 10 **voltou a ficar ligado** (tinha sido desligado de propósito em 08/08); com o pré-chat exigindo e-mail ele nunca dispara, então é inofensivo — mas é redundância que engana quem for depurar.

---

## ✅ A segunda conta em produção — e o que ela quebrou (11–15/08)

`dagente` (conta 2) é o primeiro inquilino além da PRS: bot **Vitor**, widget no ar em `www.consultasdagente.com.br`, e as inboxes 20 (voz), 21 (widget), 22 (WhatsApp) e 23 (formulário do site). Foi montando ela que se descobriu que **três credenciais do workflow do bot eram fixas da conta 1** — funcionavam por acidente, porque só existia uma conta.

| o que era fixo | como falhava | onde vive agora |
|---|---|---|
| secret do Guard (`$env.CHATWOOT_WEBHOOK_SECRET`, do bot Nathan) | assinatura nunca batia: execução vermelha e **mensagem nunca respondida**, sem sintoma nenhum para quem escreveu | `bot_channel_routes.chatwoot_agent_bot_secret` |
| token de User do `Historico` | 401 "You are not authorized to access this account" | `bot_account_settings.chat_user_token` (tabela nova, por conta) |
| token do bot em `Responde`/`Handoff` | 401 "Bot is not authorized to access this account" (`account_accessible_for_bot?`) | `bot_channel_routes.chatwoot_agent_bot_access_token` |

Os três saem de uma consulta do próprio Guard no começo da execução e viajam no JSON até os nós seguintes — `Historico`, `Responde` e `Handoff` trocaram credencial fixa por header `api_access_token` calculado por expressão (`1043c316c`, `821c8ec09`). **Conferido no workflow ao vivo em 15/08**: o `CHATWOOT_WEBHOOK_SECRET` só sobrevive num comentário.

~~**O que continua manual: o `chat_user_token`.**~~ — **provisionado automaticamente desde 19/08.** Era o terceiro credencial por conta e o único sem dono no código: secret e access_token do bot já viajavam junto da rota, e este precisava da linha em `bot_account_settings` gravada à mão antes de a conta responder. Era onde o terceiro inquilino ia travar, com o sintoma de sempre: bot mudo.

Grava quem cria rota de bot, que são exatamente dois caminhos e ambos foram cobertos: `RoutesController#ensure_chat_user_token` (Bot Personas → Channels) e `Openwa::ProvisionService#create_bot_route` (sessão de WhatsApp, que escreve a rota sem passar pelo controller). Os dois chamam `Botlayer::Client#upsert_account_settings`, upsert por `chatwoot_account_id`.

**De quem é o token, e por que isso não é detalhe:** do admin que liga o bot no canal. Quem chega ali passou por `check_admin_authorization?`, então é sempre admin daquela conta e o token vale para ela — é o mesmo critério que o provisionamento do OpenWA já usava para o `apiToken` do adapter. O preço: **admin que sai da conta leva o token junto**. Não é silencioso — o `Historico` passa a dar 401 e a execução fica vermelha na lista do n8n —, e o conserto é qualquer outro admin salvar o canal, que regrava. É por isso que a escrita é a cada save, e não só na criação.

Contas 1 e 2 já têm a linha do backfill antigo; a primeira vez que alguém salvar um canal nelas, o token é substituído pelo de quem salvou.

**`fetch` não existe no Code node** (`635a45a1f`). O n8n roda o código num `@n8n/task-runner` separado, mesmo com Node 24 no container: `require('https')` é o caminho, já liberado por `NODE_FUNCTION_ALLOW_BUILTIN=crypto,https`. Não falha em teste de sintaxe — só na primeira chamada real.

Os outros vazamentos entre contas achados na mesma onda:

- **Sessões de WhatsApp** (`986ec3eb4`): o gateway OpenWA não tem conceito de conta, então `sessions()` devolvia todas, e `qr/start/stop/logout/destroy` aceitavam qualquer `session_id` — dava para controlar a sessão de outra conta sabendo o id. Agora filtra pelo `accountId` que o provisionamento já gravava na config da instância do adapter. Sessão sem instância vinculada não tem dono identificado e some para todo mundo, em vez de ser de todos.
- **Bot de texto em inbox de voz** (`8e9408114`): a inbox `Voz — <número>` só guarda a transcrição da ligação — quem conversa é o `cortexgen-voice`, direto pela persona da rota. Ligar um AgentBot nela fazia cada trecho da transcrição virar pergunta para o workflow de texto, e foi esse o "bot respondendo tudo errado" da dagente. Ativar agora é barrado; desativar continua livre, para desfazer o que já ficou ligado.
- **Features por conta no Super Admin** (`c4d003e9c`): a tela de checkboxes é enterprise-only, então com `DISABLE_ENTERPRISE=1` não existia campo nenhum — não dava para ligar `bot_personas`/`whatsapp_sessions`/`ai_providers`/`twilio_integration` numa conta nova pelo painel.

Do lado de voz, na mesma janela: o formulário público de demo passou a existir (`7fcfc410f`) — grava consentimento e telefone em `VoiceCallRequest` **antes** de discar, porque é o registro exigido para ligar com voz automatizada, não um log — e a rota é escolhida pelo DDI do telefone digitado (`47a785f43`), o que aceita país novo sem deploy. Número só de voz deixou de aparecer como "Not connected yet" na aba Numbers (`4aca29703`).

### O formulário do site da dagente não tinha workflow — e o site engolia o erro (15/08)

O simulador de `www.consultasdagente.com.br` faz `POST` em `n8n.cortexgen.cloud/webhook/dagente-lead`, e **o workflow nunca existiu**: 404 desde a publicação. Ninguém percebeu porque o site trata sucesso e falha do mesmo jeito —

```js
fetch(url, {...}).then(r => finish(r.ok)).catch(() => finish(false));
```

— os dois caminhos abrem o WhatsApp com o resumo e mostram uma mensagem amigável. Quem preencheu e não mandou a mensagem **não deixou rastro além do evento `lead_qualificado` no GTM** (contagem, sem nome nem telefone). Esses leads não são recuperáveis.

Entregue: inbox **23 — `Site — Da Gente`** (`Channel::Api`, sem agent bot) e o workflow **`DaGente — Lead do site`** (`lBvaTfJxM6u6ZVhd`), publicado no mesmo path que o site já chama — **nada mudou no site**.

```
Webhook → Valida → Credenciais → BuscaContato → MontaContato → SalvaContato → IdDoContato → Conversa → Mensagem
```

Quatro decisões que não aparecem na tela:

- **CORS explícito** para `consultasdagente.com.br`, com e sem `www`. É `fetch` de browser com `content-type: application/json`, ou seja tem preflight: sem `allowedOrigins` o `OPTIONS` reprova e o lead morre **sem erro visível em lugar nenhum**. Verificado: 204 com o `access-control-allow-origin` certo.
- **Token por conta, lido do Supabase** (`bot_account_settings`), o mesmo caminho do Guard. Credencial fixa aqui seria o bug de 13/08 outra vez. Token de Agent Bot não serviria: `contacts` e `conversations` estão fora da `BOT_ACCESSIBLE_ENDPOINTS`.
- **Dedupe por E.164.** O campo do site aceita qualquer formatação e a busca do Chatwoot é "contém", então só a igualdade exata do número normalizado conta como o mesmo contato. O `source_id` da conversa é o telefone, então o `ContactInboxBuilder` reaproveita o vínculo: lead repetido atualiza o contato e cria só a conversa, que é o evento.
- **Falha alto.** Lead sem nome ou com telefone inválido levanta erro e aparece vermelho na lista do n8n; só o honeypot é descartado calado. **O consentimento é registrado, não é porteira** — recusar aqui perderia um lead que o site já mandou para o WhatsApp.

Provado com dois POSTs reais: contato único, `location` preenchido, atributos atualizados no segundo envio, duas conversas abertas com a fala do visitante como `incoming`. Contato e conversas de teste apagados em seguida.

**Não confundir com o pré-chat do widget**: os campos Nome/Telefone/E-mail da inbox 21 são nativos do Chatwoot e já gravam no contato, sem passar por n8n.

**Armadilha do SDK do n8n, custou uma versão:** `wf.add(ifNode).to(a, { outputIndex: 0 })` + `.to(b, { outputIndex: 1 })` **valida verde e grava as duas conexões na saída 0** — o IF deixa de ser IF e os dois ramos rodam para todo item (aqui: atualizar e criar o mesmo contato). É a mesma família do "parâmetro fora de `config.parameters` grava o nó vazio" já registrado adiante. Confira `connections` no sqlite antes de publicar; e, quando o desvio for simples, um nó só com `method`/`url` por expressão (`={{ $json.contactId ? "PUT" : "POST" }}`) elimina a armadilha junto com o nó.

~~**Pendência: o workflow `dagente-bot` (`M1DjJDW9oQA30uyq`) está ativo e órfão**~~ — **arquivado em 19/08.** Era cópia do Nathan feita em 13/08, com o Guard antigo de segredo fixo e credenciais fixas em `Historico`/`Responde`/`Handoff`; ninguém apontava para ele (o Vitor usa `cortexgen-bot`), mas quem repontasse voltava direto ao bot mudo. Despublicado e arquivado pelo MCP do n8n (`unpublish_workflow` → `archive_workflow`), com o path `/webhook/dagente-bot` desregistrado junto. Arquivar não apaga: reverter é desarquivar pela tela do n8n — e quem fizer isso herda o Guard velho, então republique só depois de trocar o nó pelo `ops/n8n/guard.js`.

---

## ✅ O botão de ligar na conversa — entregue e validado em chamada real (11/08)

Chama-se **Call demo** e vive no cabeçalho da conversa, ao lado do ícone de ligação nativo do Chatwoot. Abre um diálogo com o número do contato já preenchido, o número que vai discar e a persona (em branco = a da rota), e chama o `POST /api/v1/accounts/:id/integrations/twilio/voice_calls` que já existia.

Por que ele e não uma landing: pré-chat, campanha do widget, WhatsApp e e-mail **todos terminam numa conversa com um contato que tem telefone**. Um botão ali serve os quatro; uma landing serve um.

Onde está: [CallDemoButton.vue](app/javascript/dashboard/components/widgets/conversation/CallDemoButton.vue), montado em [ConversationHeader.vue](app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue).

Três decisões que estão no código e não são óbvias na tela:

- **O botão só aparece para administrador**, porque o endpoint é admin-only como o resto da integração — uma ligação custa dinheiro e toca no telefone de alguém. Se um agente precisar disparar, a mudança é no `BaseController` da integração, não aqui.
- **O telefone do contato entra preenchido, mas editável.** Contato gravado sem código de país é comum, e o Twilio recusa o que não for E.164 com uma mensagem que não diz que o problema é o formato.
- **O cache de rotas e personas vive em [voiceBotCall.js](app/javascript/dashboard/helper/voiceBotCall.js), fora do componente.** O topo de um `<script setup>` roda por instância: deixar o cache lá dentro daria dois requests a cada conversa aberta. O botão precisa da lista de rotas para decidir se aparece, então a busca não dá para adiar até o clique.

**Validado pelo log do Rails**, que é o único jeito de provar que o JS rodou:

```
01:52:35  GET  .../voice_routes   de 190.218.47.180   ← loadBotRoutes, decide se o botão aparece
01:54:07  POST .../voice_calls    de 190.218.47.180   ← o clique
01:57:47  POST .../voice_calls    de 127.0.0.1        ← a mesma chamada por SSH, para comparar
```

**Chamada disparada por SSH não valida o botão.** Ela exercita controller e serviço, que já estavam validados desde 10/08. O IP do navegador no log é a prova, e o `GET voice_routes` antes do POST é o que distingue "o botão apareceu" de "alguém chamou a API".

**Armadilha ao testar o endpoint por dentro do container:** sem `X-Forwarded-Proto: https` ele responde **308**, não 200 — o mesmo detalhe que o smoke test do protocolo de deploy já exige. Pelo navegador não acontece, porque o nginx põe o header.

Decisões já tomadas, para não reabrir:

- **Não usar pré-chat como portão.** Ele aparece para todo visitante antes de deixá-lo falar com o bot. Precedente do próprio projeto: o email collect box foi desligado na inbox 10 em 08/08 porque *"o prompt do Nathan já pede e-mail no momento certo"*. Vale igual para telefone. Se quiser mesmo, ative o campo como **opcional**.
- **Campanha de Live Chat é o gancho**, não o formulário: dispara por URL + tempo na página e **cria a conversa**, onde o Nathan de texto já vive. Campanha nenhuma disca — o executor tem três ramos (`Twilio SMS`, `Sms`, `Whatsapp`) e nenhum de voz.
- **Ligar automático fica para depois.** Primeiro um humano no meio, para ver o que acontece quando alguém digita o número errado.

### ▶️ RETOMAR AQUI — o bot conversava com o correio de voz (11/08, `5d970c267`)

**Consertado. Provado por dentro em 19/08; falta só ver a Twilio derrubar uma chamada viva.**

A prova sem gastar chamada foi além do 403/404 descrito adiante: um webhook **assinado de verdade** (assinatura gerada no próprio servidor com o `RequestValidator` da Twilio, sobre um `TwilioVoiceCall` descartável de SID inexistente) exercita o caminho inteiro. Matriz completa, contra a produção em `821c8ec09`:

| `AnsweredBy` | HTTP | status gravado | tentou desligar? |
|---|---|---|---|
| `unknown` | 200 | intacto (`ringing`) | não — correto, o Twilio não decidiu |
| `human` | 200 | intacto (`ringing`) | não |
| `machine_start` | 500 | `machine_start` | **sim** |
| `machine_end_beep` | 500 | `machine_end_beep` | **sim** |
| `fax` | 500 | `fax` | **sim** |

**O 500 é o sinal de sucesso, não de defeito:** significa que o `hang_up_call` chegou a falar com a Twilio e ela respondeu `[HTTP 404] 20404 Unable to update record` porque o `CallSid` da sonda é falso. Com um SID vivo, essa é a chamada que derruba. O log traz a linha que faltava:

```
TWILIO_VOICE_AMD_HANGUP sid=CAffff…ffff answered_by=machine_start
Twilio::REST::RestError ([HTTP 404] 20404 : Unable to update record
app/controllers/twilio/voice_routing_controller.rb:62
```

Ficam provados: rota resolvida pelo `CallSid` (o bug de `0e9052981`), assinatura validada, a porteira do `MACHINE_ANSWERS` nos dois sentidos, o `update_call_status` e a ida à REST da Twilio com a credencial da conta certa. **Não fica provado** que a Twilio encerra a chamada e que a duração cai para segundos — isso só uma ligação real mostra.

**Efeito colateral que vale saber antes de vê-lo em produção:** se o webhook do AMD chegar para uma chamada que já terminou (quem atendeu desligou no exato momento da decisão), o `hang_up_call` toma o mesmo `20404` e o endpoint devolve **500**, com retry do lado da Twilio. É barulho, não perda — a chamada já acabou —, mas explica um 500 solitário no log que não é regressão.

Duas ligações para o celular do Paulo caíram no correio de voz da Más Móvil, e o bot **conversou com o menu da operadora**: 150 s e 155 s, 7 e 8 turnos, alternando pergunta de diagnóstico com *"presione siete para revisar su mensaje"*. O Twilio trata "atendido pela gravação" como atendido, conecta o `<Stream>`, e nada desligava.

**A causa não foi "ninguém atendeu" — foi o Não Perturbe por horário do celular.** Isso é bom: torna o cenário **reproduzível sob demanda**. Para testar o AMD, ligue para um número com DND ativo em vez de esperar uma chamada perdida acontecer. Chamada US → US no mesmo período foi atendida e conversou normalmente, então não é o botão nem a rota.

O detalhe que dói: às 01:55:52 o próprio modelo disse **"Parece que está escuchando un mensaje automático"** — e seguiu perguntando. É o mesmo padrão do bot que se despedia e ficava na linha: o modelo nota, mas nenhum código age. **Quando o modelo percebe algo e nada acontece, o que falta é um observador, não prompt.**

Conserto: `machine_detection` no `Voice::OutboundCallService` + `POST /twilio/voice/amd_status` no `Twilio::VoiceRoutingController`, que derruba a chamada por REST.

**Assíncrono de propósito** (`async_amd`). No modo síncrono o Twilio só pede o TwiML depois de decidir, e quem atende de verdade ouviria alguns segundos de silêncio a mais em **toda** chamada boa — caro num projeto cujo gargalo declarado é latência. Assim a chamada começa na hora e o webhook a derruba depois.

**`AnsweredBy=unknown` não derruba.** O Twilio não decidiu; desligar na cara de um humano é pior que pagar por uma secretária ocasional.

**O webhook do AMD chega com quatro campos e nenhum telefone** — e isso custou uma versão:

```
MachineDetectionDuration, CallSid, AnsweredBy, AccountSid
```

A primeira versão resolvia a rota pelo `From`, como o `outgoing`. Ele não vem. O `set_route` devolvia 404 e o hangup nunca rodava — **sem erro nenhum no log além de um `Filter chain halted as :set_route`**, que é precisamente o tipo de falha silenciosa que este endpoint existe para evitar. Visto em produção: `AnsweredBy=machine_start` detectado em 2.980 ms, e a chamada seguiu viva até o humano desligar.

Corrigido em `0e9052981`: a rota sai do `TwilioVoiceCall` já gravado, pelo `CallSid` — o único identificador que o webhook traz.

**Dá para provar sem gastar chamada.** Suba a `:test` na 3099 e mande o webhook com um `CallSid` real: **403** significa que a rota resolveu e só a assinatura barrou (correto); **404** significa que o `set_route` ainda falha. Um `CallSid` inexistente deve continuar dando 404.

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H 'X-Forwarded-Proto: https' -H 'Host: prs.cortexgen.cloud' \
  -d 'CallSid=<sid real>' -d 'AnsweredBy=machine_start' \
  http://127.0.0.1:3099/twilio/voice/amd_status
```

**Pendência conhecida:** o `CallReportService` não tem piso mínimo, então mesmo derrubada em segundos a chamada ainda vira conversa — curta e vazia, em vez de 155 s com lead extraído. Resolver é no serviço Python, outro deploy; o custo, que era o problema, já está resolvido.

**O CRM não foi corrompido:** `lead_fit = LOW` nas duas (o extrator acertou em classificar a gravação). As conversas 67 e 68 foram apagadas; a 66 é legítima.

### O estado hoje, em uma tela

| | estado |
|---|---|
| Voz entrando | ✅ atende, qualifica, registra no CRM e **desliga sozinho** |
| Voz saindo | ✅ disparo pelo painel, persona `nathan-es-demo`, validado |
| Latência | ~1,9–2,2 s de espera real. **O alvo de 1,5 s nunca foi batido** — a régua antiga media o pedaço errado |
| Números | `+16893539100` (US) e `+5078389480` (Panamá), os dois roteados para o bot |
| E-mail | ✅ saída por Resend, entrada por Mailgun, os dois provados |
| Isolamento entre contas | ✅ persona, base de conhecimento, sessões de WhatsApp e **credenciais do bot** por conta |
| Segunda conta | ✅ `dagente` em produção: widget, WhatsApp, voz e formulário do site (ver o topo) |
| Webhook do bot | ✅ exige assinatura do Chatwoot |
| Marca | ✅ arte, tema verde e nome em 57 idiomas |

Config de voz ativa:

```
stt : deepgram flux-general-multi · language_hints=[es, pt] · eot_threshold 0.70 (campo da persona)
llm : OpenAI DIRETO, gpt-4.1-mini (sem o prefixo `openai/`, que é do OpenRouter)
tts : eleven_flash_v2_5 · voz ny3E2DZImeZm00WLGZi9
personas: nathan-es-voice (recepção, 24,7 KB) · nathan-es-demo (saliente, 11,6 KB)
```

`eager_eot_threshold=0.5` e `eot_timeout_ms=5000` seguem chumbados no `_stt`. Só o `eot_threshold` virou campo.

### O que esta sessão mudou de ideia, e vale ler antes de otimizar

Três coisas que estavam escritas aqui como verdade e não eram:

1. **"Mediana de 1.268 ms, alvo batido"** — a régua media do `EndOfTurn` em diante e ignorava ~0,8 s de silêncio em que quem ligou já tinha calado. A espera real é ~2,2 s.
2. **"Encurtar o prompt reduz latência"** — não reduz. A OpenAI cacheia o prefixo (6.272 de 6.470 tokens vêm do cache, visível no log de todo turno). Cortar o prompt pela metade não moveu o relógio.
3. **"O card OpenAI é morto"** — não é. É cofre de chave por conta, e o assistente de escrita foi testado e funciona.

### A fila, na ordem que eu seguiria

~~O botão de ligar na conversa~~ — **entregue e validado** em chamada real (acima).

1. ~~**Arquivar o `dagente-bot`**~~ (`M1DjJDW9oQA30uyq`) — **feito em 19/08** (topo).
2. ~~**Provisionar o `chat_user_token`**~~ — **código pronto em 19/08, falta subir** (topo). Escrito, sem deploy: exige o protocolo de deploy (build `:test` antes) e, à parte, uma passada no nó Guard para levar a mensagem de erro nova (`ops/n8n/guard.js` diverge do workflow ao vivo só nessa string).
3. **Provar o AMD** — **provado por dentro em 19/08** (matriz de `AnsweredBy`, log e chamada à REST da Twilio, acima). Falta só a ligação real para um número com Não Perturbe ativo, para ver a duração cair para segundos.
4. **Custo e capacidade** — hoje há tokens e segundos por chamada, mas não tarifa: não dá para saber margem. E ninguém mediu quantas chamadas simultâneas a VPS aguenta. São as duas surpresas da primeira conta que usar de verdade.
5. **DNS secundário** — `ns1`/`ns2.dns-parking.com` são os dois da Hostinger. Foi o que derrubou duas chamadas em 10/08. Conserto é no registrador, não no código.
6. **Cloudflare RealtimeKit** — em stand by, token reprovado na validação. Script pronto em `ops/set-realtimekit.sh`.
7. **`lead_fit` vazio** — a extração devolve nulo ou categoria fora do vocabulário, e o código descarta **em silêncio**. Falta uma linha de log em `call_report_service.rb` para distinguir os dois casos.
8. **Latência**, se ainda incomodar: o único componente gordo que é nosso é a espera do EOT (~0,8 s). O caminho de verdade é o **EagerEndOfTurn**, que o Flux já anuncia em 0.5 e o Pipecat deixa para a aplicação implementar. É a maior mudança do projeto.

### Como a latência caiu de 2.256 para 1.146 ms

Quatro ajustes, um por chamada, cada um medido antes do seguinte:

| | mediana | o que mudou |
|---|---|---|
| Flux inicial | 2.256 ms | — |
| debounce 0.2 | 2.166 ms | `ExternalUserTurnStopStrategy(timeout=0.2)`. O padrão de 0,5 s espera transcrição atrasada; o Flux entrega o texto **junto** com o `EndOfTurn`, então era espera por algo que já chegou |
| TTS flash | 1.683 ms | `eleven_flash_v2_5` no lugar do `multilingual_v2`: primeiro áudio de 0,55 s → 0,19 s |
| `eot_threshold` 0.8 | 1.775 ms | **subiu** 92 ms de propósito — ver abaixo |
| OpenAI direto | **1.146 ms** | tirar o hop do OpenRouter valeu ~700 ms. TTFB do LLM: 1,2–1,6 s → 0,4–0,7 s |
| retry 3 s → 5 s | estável | **um retry nunca faz quem ligou esperar menos**: descarta o request e refaz o prefill. Com 3 s, três de quatro turnos esperaram 9,8 / 7,9 / 7,6 s; o único sem retry respondeu em 1,3 s |

Medições posteriores com prompt maior: **1.268–1.340 ms** de mediana em amostras de 9 e 18 turnos. O alvo se sustenta.

**A ordem importa.** O `eot_threshold` só pôde subir porque o flash tinha comprado 480 ms antes. Com 0.7 o Flux fechava o turno na pausa natural: *"Doutor Juan"* chegou como `'Doutor,'` + `'one.'` e custou **três idas e voltas** para capturar um nome; *"Clínica Luis / Soy médico / tenemos atención"* virou três turnos de uma frase. Blips de 115 ms também contavam como fala.

**O flash não criou os estalos que apareceram junto — tornou-os audíveis.** Com o `multilingual` o primeiro áudio levava 550 ms, e uma micro-interrupção de 115 ms chegava antes de existir som: cancelada em silêncio. Com 190 ms, o mesmo corte acontece depois da sílaba começar. O defeito era antigo; mudou a faixa audível.

**Pendência da troca de provider:** a reserva continua apontando para o OpenRouter e agora é recusada (`fallback ... ignored: a call cannot switch providers mid-stream`). A chamada roda **sem rede** — só o `retry_on_timeout` de 3 s. Conserto no painel: Fallback provider → "Same as primary", modelo `gpt-4.1`.

**Cuidado com o ID do modelo:** `openai/gpt-4.1-mini` é formato OpenRouter. Apontando para `api.openai.com` ele devolve `400 invalid model ID` e a chamada morre logo depois da saudação.

### Os três defeitos da abertura, na ordem em que foram achados

**1. O idioma que mandávamos ao Flux nunca saiu do processo.** O `_build_query_string` do Flux monta `model`, `sample_rate`, `encoding`, os thresholds, `keyterm`, `tag` e `language_hint` — e nada mais. O campo `stt_language` da persona (`multi`) jamais chegou à Deepgram; quem segurava o multilíngue era só o sufixo do modelo, sem viés. Numa linha de 8 kHz ele passeava: quatro segundos de espanhol voltaram como *"Es traurige Saussurer gravata paraffins de quali ditti"*. Corrigido com `language_hints=[Language.ES, Language.PT]`.

**2. O Flux alucina uma frase de estoque sobre o quase-silêncio da linha, e ela matava a saudação.** Cinco chamadas, sempre o mesmo esqueleto — `estado de casa … de Quality ID` — **inclusive uma com o microfone de quem ligou mudo**. O Flux declarava turno em cima disso, a interrupção cortava a saudação antes de *"¿Cuál es su nombre?"*, e o bot ainda respondia à alucinação com "No entendí bien". O gatilho entrava no **primeiro segundo, antes de o bot emitir um byte**. Corrigido com `SilenceUntilBotHasSpoken`, um processador **antes do STT** que nasce fechado e abre no primeiro `BotStoppedSpeakingFrame`.

**3. O Twilio descartava os ~3 primeiros segundos de áudio.** Falávamos os 5,9 s inteiros e quem ligou só ouvia a partir de *"…ese Brands"*. Só a **primeira** fala perdia o começo; as seguintes chegavam inteiras — assinatura de caminho de voz ainda não cortado na operadora. Corrigido subindo `Wait before speaking (ms)` de 300 para **2500** na persona.

### Duas hipóteses descartadas com instrumentação, não com opinião

Custaram um deploy cada e valem o registro, porque as duas eram plausíveis:

- **"O Twilio nos devolve a nossa própria pista."** O `deserialize` do `TwilioFrameSerializer` de fato não filtra por `track` — todo evento `media` vira áudio de entrada. Mas o contador no `CallerAudioOnlySerializer` mostrou `{'inbound': 2651}`, **zero outbound**. O filtro ficou (é higiene correta), provado inócuo.
- **"É eco da nossa voz voltando pela linha."** Derrubada pelo relógio: numa chamada o turno fantasma abriu a partir de áudio capturado quando o bot ainda estava mudo. O que parecia eco era a alucinação do item 2 — o esqueleto repetido entre chamadas vinha do modelo, não do áudio.

O log de fim de chamada carrega as duas provas em toda ligação: `audio tracks {...}, echo frames silenced N`.

### O preço aceito: não há mais barge-in

Com a porteira fechada durante a fala do bot, **quem ligou não consegue cortá-lo**. Um "aló" durante a abertura também se perde. É o que um cancelador de eco compraria de volta — e nenhum está instalado: dos quatro filtros do Pipecat (`rnnoise`, `koala`, `krisp_viva`, `aic`), só o RNNoise é livre, e ele é supressão de ruído, não cancelamento de eco.

O `Teste 4` do protocolo abaixo está, portanto, **reprovado por desenho**. Não é regressão a investigar.

### O prompt: o que se aprendeu escrevendo-o

O prompt da persona de voz foi reescrito nesta sessão, e três lições valem mais que o texto:

**Só a lista final é obedecida de verdade.** Num prompt de 15 KB, o modelo ancora no último bloco. Regra que estava em `REGLAS DE MÁXIMA PRIORIDAD` era cumprida (tamanho de resposta, pergunta única); regra que estava só no corpo era ignorada (começar perguntando por que ligou, separar mostrar de pedir o canal). **O que tiver de valer, põe na lista.**

**Exemplo negativo pega; regra abstrata não.** "Una sola pregunta por turno" só passou a valer quando ganhou um par incorreto/correto. O mesmo formato depois resolveu a pergunta conduzida e a junção de passos.

**Frase entre aspas o modelo copia inteira.** As rotas de triagem tinham a pergunta embutida na fala de cortesia, e ao trocar de rota no meio da chamada o bot repetiu uma pergunta já respondida — quem ligou disse "ya hablé" e desligou. Correção: separar a frase da lista de dados, e dizer *"pide solo lo que falte"*.

**E o extrator não é o bot.** A classificação do lead (timeline/interés/fit) saía do prompt vivo a cada turno e **nada lia o resultado**. Passou para a leitura pós-chamada, que vê a conversa inteira. Junto foi uma guarda que faltava: sem ninguém perguntar a empresa de quem ligava, o extrator achava o único nome de empresa do transcrito — **o nosso** — e o CRM passou a dizer que o lead trabalha na PRS Brands.

### Fila, na ordem que eu seguiria

Nada aqui bloqueia atender uma chamada real.

1. ~~O coletor de métricas está quebrado no Flux~~ — **consertado** em `441049df6`, **falta uma chamada para confirmar** (ver abaixo).
2. **O prompt voltou a crescer e passou do ponto de partida**: 22,2 KB no início da sessão, 19,6 KB depois do corte, **23,4 KB hoje** (5.751 tokens medidos) — reenviados por turno. Se voltar a aparecer `Retrying`, os cortes naturais são os blocos de **objeções** e os **exemplos por rubro**: os mais longos e os que menos entram numa chamada típica. **Mas não corte esperando latência** — ver abaixo.
3. **A reserva do LLM não existe.** Com o primário na OpenAI direto, o cascade é recusado (o array `models` só existe no OpenRouter). Só o `retry_on_timeout` de 5 s protege. As três opções — voltar ao OpenRouter e perder ~700 ms, ficar sem rede, ou construir um segundo request pós-erro — estão avaliadas em "pendência da troca de provider" acima. Ficar sem rede foi a escolha consciente.
4. ~~Campos mortos no painel~~ — **resolvido** em `711737a91`: somem quando o modelo é `flux-*`, e no lugar entra **End of turn confidence** (`bot_personas.voice_eot_threshold`, CHECK 0.50–0.95, padrão 0.80). **Falta procurar o ponto** — ver abaixo.
5. **`keyterm` do Flux, ainda não usado.** Enviesa o reconhecimento para termos do domínio (*venta, cita, taller, agendar, seguimiento*). Uma linha no `_stt`. Vale depois que um sintoma de transcrição justifique.
6. **Voz humana de fundo** segue sem teste. Ambiência (rua, música) passou — 5 turnos, 5 falas, zero turno fantasma, e 10 s de silêncio no fim sem disparo. Colega falando ou TV com diálogo é outra história, e nenhum filtro grátis resolve (`rnnoise` é supressão de ruído, não separação de locutor).
7. **Baixar o `greeting_delay_ms` para 2000** e ver se ainda aguenta. 2,5 s de silêncio ao atender é muito.

### A latência era medida por um quadro que o Flux nunca emite (10/08, `441049df6`)

O `UserBotLatencyObserver` do Pipecat só começa a cronometrar quando vê um **`VADUserStoppedSpeakingFrame`** — o quadro do VAD, não o genérico. Sob Flux a máquina de turnos vive dentro do serviço de STT e o VAD sai do pipeline ([bot.py:485](services/cortexgen-voice/app/bot.py:485) e [:537](services/cortexgen-voice/app/bot.py:537)): esse quadro nunca nasce, o relógio nunca parte e `on_latency_measured` nunca dispara. O Flux emite `UserStoppedSpeakingFrame`, que o observador usa só para outra conta.

O sintoma enganava porque **o resto do coletor funcionava**: as cinco últimas chamadas gravaram tokens, caracteres e segundos de áudio corretos, e só a latência ficou nula. E `turns` saía do tamanho da lista de latências, então zerou junto — uma chamada de 104 s com 53 mil tokens de prompt aparecia com zero turnos.

O `CallMetrics` passou a cronometrar sozinho, e o `UserBotLatencyObserver` saiu. Turnos agora são contados no evento.

**A medição inclui a espera do EndOfTurn, de propósito.** O `EndOfTurn` não chega quando a pessoa cala: o Flux precisa de silêncio para a confiança passar do `eot_threshold`. Contar só dali para frente esconderia o preço de subir 0.7 → 0.8 justamente na métrica que existe para medi-lo. O payload da Deepgram traz `audio_window_end` e `words[].end` — ambos em segundos do **mesmo** stream, então a diferença é uma duração e não exige casar o relógio deles com o nosso, que é onde esse tipo de medida derrapa. Na rota Nova os campos não existem, a função devolve 0 e a contagem começa na liberação do turno.

**O `smoke.py` reprova a versão anterior**: alimenta o `UserBotLatencyObserver` com a sequência real de um turno Flux (`TranscriptionFrame` com o payload de EOT → `UserStoppedSpeakingFrame` → `BotStartedSpeakingFrame`) e exige zero medições. Cobre também a saudação não virando turno e o irmão upstream do `broadcast_frame` não contando duas vezes.

**Confirmado na chamada `CAe22d9e1a51dd2ab74b0707e9a27b2b56`** (10/08, 104 s): `turns: 7`, mediana **2.211 ms**, pior **3.131 ms**. Os 7 turnos batem com os 7 `EndOfTurn` do log; só 5 viraram latência porque em dois deles quem ligou voltou a falar antes de o bot começar — turno superado não tem espera para medir, e é assim que deve ser.

### O alvo de 1,5 s nunca foi batido — a régua media o pedaço errado

Conferência manual da mesma chamada, do `EndOfTurn` ao primeiro áudio: 2,40 · 1,18 · 1,33 · 1,76 · 1,26 s (mediana 1,33 s). O gravado deu 2,21 s. **A diferença de ~0,7–0,9 s é a espera do EOT**, que a leitura manual nunca contou porque começava no evento que só existe depois dela. É silêncio com quem ligou já calado, esperando.

Isso corrige duas coisas escritas aqui antes:

- **A mediana de 1.268 ms não era a espera de quem liga**, era o trecho a partir do EOT. A espera real está em ~2,2 s, acima do alvo de 1,5 s. O critério de "usável" continua batido — a conversa acontece, qualifica e registra —, mas o alvo de latência não.
- **Subir `eot_threshold` de 0.7 para 0.8 não custou 92 ms.** A medição da época era cega à janela inteira. O custo real está na casa dos 800 ms.

Os três componentes da espera, medidos nesta chamada:

| | típico | knob |
|---|---|---|
| espera do EOT | ~0,8 s | `eot_threshold`, chumbado no código |
| LLM TTFB | 0,29–1,87 s | tamanho do prompt e modelo |
| TTS TTFB | ~0,135 s | já no fundo do poço |

### Cortar o prompt não baixa a latência — medido, não estimado

Antes de reescrever o prompt para ganhar tempo, este experimento contra a própria OpenAI (mesmo modelo, `max_tokens=1`, três chamadas de cada):

| prompt | tokens | tempo até o primeiro byte | cache |
|---|---|---|---|
| cheio (23,9 KB) | 5.751 | 1.134 · 665 · **803** ms | 3.968–5.504 lidos do cache |
| pela metade (11 KB) | 2.773 | 811 · 981 · **507** ms | 2.560 lidos do cache |

**Cortar o prompt pela metade não moveu o relógio** (mediana 803 contra 811 ms). A OpenAI cacheia o prefixo — na segunda chamada, 5.504 dos 5.751 tokens vieram do cache —, então o prefill do nosso prompt já é quase de graça. A variação de 507 a 1.134 ms é jitter do fornecedor e é maior que qualquer efeito do tamanho.

Encurtar o prompt continua valendo por **qualidade de conversa e risco de retry**, como já estava escrito aqui. Não vale por latência.

**O próprio log de produção confirma**, e ninguém tinha reparado — o Pipecat já imprime a conta em todo turno:

```
OpenAILLMService#0 prompt tokens: 6470, completion tokens: 13, cache read input tokens: 6272
```

6.272 dos 6.470 vão cacheados. O `CallMetrics` ainda não grava `cache_read_input_tokens`; gravar tornaria isso visível por chamada em vez de depender de alguém ler o log.

Sobra o EOT como o único componente gordo que é nosso: ~0,8 s controlados pelo `eot_threshold`, hoje chumbado no código (item 4 da fila).

### O limiar de fim de turno virou campo — e é o único knob de latência que sobrou

`bot_personas.voice_eot_threshold` (SQL em `db/botlayer/bot_voice_eot.sql`, aplicado), CHECK 0.50–0.95, padrão **0.80**. Aparece no editor de persona como **End of turn confidence**, só quando o modelo de transcrição é `flux-*`.

É confiança, não milissegundos de silêncio — e é onde mora ~0,8 s da espera de quem liga. **Cada tentativa agora custa uma chamada, não um deploy.** Procure o ponto em passos de 0.05, uma ligação por passo, olhando `latency_median_ms` no banco e o Teste 3 (soletrar) logo depois: 0.70 é o padrão da Deepgram e aqui fragmentava a fala, então descer é justamente o que precisa de prova.

Os três campos que não faziam nada sob Flux **somem** quando o modelo é `flux-*`, em vez de ficar na tela parecendo configurados:

| Campo | Onde morria |
|---|---|
| **End of turn (ms)** | alimenta o VAD do Silero (`None` no Flux) e o ramo Nova do `_stt` |
| **Wait until the caller finishes** | vive em `_turn_strategies`, que a rota Flux contorna |
| **Words needed to interrupt** | mesma função, mesmo desvio |

Vivos: `Wait before speaking (ms)`, `Customer can interrupt`, `First message`, voz e idioma do TTS. `eager_eot_threshold` (0.5) e `eot_timeout_ms` (5000) seguem chumbados de propósito — o eager só vale a pena junto com processamento especulativo, que não existe (ver EagerEndOfTurn nas pendências).

**Armadilha ao testar o `/voice-stream` com curl:** por HTTP/2 ele responde **404**, e parece que a voz caiu. Não caiu — o HTTP/2 não tem cabeçalho `Upgrade`, então o nginx repassa vazio e o FastAPI não vê um handshake. Use `curl --http1.1`, que é como o Twilio conecta, e a resposta é **101**.

### Calibração do limiar — três chamadas, e uma lição sobre a que parece pior

| limiar | chamada | turnos | mediana | pior |
|---|---|---|---|---|
| 0.80 | 46 | 7 | 2.211 ms | 3.131 ms |
| 0.75 | 47 | 13 | 2.030 ms | 3.114 ms |
| 0.70 | 48 | 8 | **1.756 ms** | 2.694 ms |

**A chamada em 0.70 pareceu ruim e não era o limiar.** O transcrito veio limpo e quem ligou soletrou um e-mail que chegou inteiro e certo (`j o s e m a r i a arroba g m a i l punto com`) — o Teste 3 passando em 0.70, que era exatamente o risco que se temia. O que estragou a chamada foram dois defeitos de prompt, os dois já descritos aqui, e os dois acontecem igual em 0.80:

- pediu contato **já dado**: quem ligou ditou o e-mail cedo, fora da sequência, e o bot pediu de novo mais tarde → *"Já hablei meu email para ustedes"*;
- repetiu a pergunta de triagem **inteira e entre aspas** (`"¿Es para ofrecer un producto o servicio, o por otro tema?"`) ao trocar de rota → *"Ya hablé."*

Corrigidos no prompt em 10/08 (Supabase, sem deploy): a pergunta de esclarecimento ganhou condição explícita (*"si todavía no sabes a qué vino"*) com par incorreto/correto, o bloco de dados já fornecidos ganhou o exemplo do dado adiantado, e a lista de máxima prioridade ganhou a regra 4 — *"nunca repitas una pregunta que ya fue respondida, aunque este guion la traiga escrita"*. A lista também tinha **dois itens numerados 10**; agora vai de 1 a 15. Prompt: 19,3 → 20,6 KB.

**Não julgue um limiar pela qualidade da conversa** — julgue pela mediana e pelo Teste 3. O que o bot fala é do prompt.

### O bot se despedia e ficava na linha (`273205aa8`)

Faltava a peça inteira. Numa chamada de teste a despedida saiu às `17:18:13.256` e a ligação só caiu 17 s depois, **quando quem ligou desligou**. O serializer sobe com `auto_hang_up=False` e nada empurrava frame de fim — o prompt escrevia o "buen día" e nenhum código agia sobre ele.

Pior que o incômodo: sem quem ligou desligar, a rede é o `idle_timeout_secs` do Pipecat, **300 s de fábrica**. Cinco minutos de linha aberta pagando Twilio e Deepgram para transmitir silêncio.

`HangUpAfterFarewell` (observador, em `app/bot.py`) casa a despedida no texto que vai ao TTS e chama `stop_when_done()` no `BotStoppedSpeakingFrame` seguinte — depois do áudio, para não cortar o próprio tchau. **Fechar o WebSocket derruba o `<Connect>`**, então não é preciso credencial da Twilio dentro do serviço.

O gatilho é a frase, não uma decisão do modelo, pelo mesmo motivo do handoff de texto: desligar é irreversível e um `end_call` alucinado corta o cliente no meio da frase. O preço é o inverso — **despedida parafraseada não cai sozinha** —, e por isso o acerto vai para o log:

```
farewell detected: 'Que tengas buen día.' — hanging up when it finishes
```

Chamada que termina sem essa linha é despedida que escapou do casamento (`que teng\w*\s+(un\s+)?buen`). Se acontecer, o caminho é acrescentar a variação ao regex, não trocar por decisão do modelo.

**A primeira versão não disparou, e a culpa era do teste.** Numa chamada real o bot disse *"Que tenga buen día."* e a linha continuou aberta. Motivo: a ElevenLabs sobe com **`push_text_frames=False`** porque tem marcação de tempo por palavra, então o `TTSTextFrame` sai **palavra por palavra** — o regex era testado contra `'Que'`, depois `'tengas'`, depois `'buen'`, e nenhuma palavra sozinha casa uma frase. O smoke alimentava a frase inteira: uma granularidade que a produção nunca gera, verde enquanto a chamada falhava.

Corrigido em `600d4a43c` com um acumulador da fala corrente, zerado a cada `BotStartedSpeakingFrame` para não juntar o fim de uma frase com o começo de outra. **A regra vale além deste caso: quadro de texto do TTS é palavra, não frase.** Qualquer coisa que precise casar uma expressão no que o bot fala tem de acumular.

**Validado em chamada real** (`CA5e46110548e285f81d3a9a0b0e74ee33`, 10/08):

```
17:53:23.901  farewell detected: 'Nuestro equipo continúa contigo. Gracias por
              hablar con Pe-erre-ese Brands. Que tengas buen día.' — hanging up
17:53:26.517  call finished after 144s
```

**2,6 s** entre a despedida e o fim, contra os 56 s da chamada anterior. E o encerramento pelo nosso lado não atrapalhou o registro: conversa 62 criada, contato com nome, empresa (`Casa Negra`) e o e-mail soletrado (`paulo@arrowgen.com`) — o mesmo "arrowgen" que já tinha quebrado antes. 13 turnos, mediana 1.767 ms em 0.70, coerente com os 1.756 ms da calibração.

### A regra que se pagou nesta sessão

**Uma mudança por chamada** — e, quando duas hipóteses explicam o mesmo sintoma, **instrumentar em vez de escolher**. O contador de pistas de áudio derrubou uma hipótese minha em uma ligação; o relógio da abertura derrubou a segunda. Cada uma teria custado dias de conserto na direção errada.

### Protocolo de teste — siga na ordem, uma chamada por vez

Depois de **cada** ligação:

```bash
docker logs --tail 800 cortexgen-voice 2>&1 | grep -v 'Generating chat from context' \
  | cut -c1-190 | grep -iE 'call .* (started|finished)|Generating TTS|ERROR|StartOfTurn|EndOfTurn|EagerEndOfTurn|TurnResumed|TTFB'
```

E as métricas gravadas:

```bash
cd /opt/cortexgen-chat && docker compose exec -T rails bundle exec rails runner \
  "c=TwilioVoiceCall.order(id: :desc).first; puts c.duration_seconds; puts c.metrics"
```

**Teste 1 — a conversa acontece?** ✅ Ligue, responda o nome, diga a empresa, responda uma pergunta. Procure `StartOfTurn` / `EndOfTurn` do Flux.

**Teste 2 — latência.** ❌ Alvo: mediana abaixo de **1.500 ms**. Medição honesta (coletor consertado, inclui a espera do EOT): **2.211 ms** em 7 turnos. As médias de 1.268 ms registradas antes mediam do `EndOfTurn` em diante e não contavam ~0,8 s de espera — ver a seção do coletor no topo.
- Acima do alvo: confira primeiro se há `Retrying chat completion` no log — o retry dobra a espera. Depois, `eot_threshold` para 0.7.

**Teste 3 — soletrar.** ✅ Dite um e-mail letra por letra. Validado: turno de 18,8 s com pausa entre cada letra, sem corte, e o e-mail montado certo. Foi o `eot_threshold=0.8` que segurou.
- Cortou: suba para 0.9. O teto duro de 5 s continua atrás.

**Teste 4 — interromper.** ❌ **Reprovado por desenho** — a porteira contra a alucinação silencia a entrada enquanto o bot fala. Só volta com cancelador de eco licenciado. Não investigue.

**Teste 5 — português no meio do espanhol.** ✅ "Concertos de automóveis" ficou em português e o bot não repetiu a palavra de volta — conduziu a conversa inteira como oficina.

**Teste 6 — abertura.** ✅ A saudação chega **inteira**, terminando em "¿Cuál es su nombre, por favor?".
- Cortada no fim: alucinação abrindo turno — confira `start_of_turn` durante a fala do bot.
- Faltando o começo: o Twilio ainda descarta áudio; suba o `Wait before speaking (ms)`.

**Teste 7 — triagem.** ✅ Ligue **fingindo ser fornecedor** ou pedindo para falar com uma pessoa. O bot não pode fazer nenhuma pergunta de diagnóstico, e o CRM tem de gravar `lead_fit = LOW` com a empresa de quem ligou.

**Ruído de ambiente.** ✅ Rua, música, ventilador: 5 turnos, 5 falas, zero turno fantasma.

**Critério de "usável": batido em 10/08.**

### Se o Flux falhar

Volta em **um campo, sem deploy**: persona → Voz → `Transcription model` de `flux-general-multi` para `nova-3`. Todo o caminho Nova continua no código, com `interim_results` + `utterance_end_ms`, e `_turn_strategies` volta a valer.

Antes de voltar, confirme no log se o Flux chegou a conectar — se não houver `StartOfTurn` nenhum, o problema é conexão/credencial, não comportamento.

### Explicado: o "502 no webhook" era DNS, não 502 (10/08)

O alerta do Twilio resume tudo como *"Got HTTP 502 response"*, e foi por isso que este item passou uma sessão inteira como mistério. **O corpo da resposta diz outra coisa**, e são duas ocorrências, não uma:

```
10/08 02:29:07   Error: Total timeout is triggered. Configured tt is 15000ms
                 and we attempted 2 time(s). responseState=INITIAL
                 (URL http://prs.cortexgen.cloud/twilio/voice/incoming)

10/08 03:38:04   Error: Unknown host prs.cortexgen.cloud
                 (URL https://prs.cortexgen.cloud/twilio/voice/incoming)
```

**O Twilio não resolveu o nome.** `responseState=INITIAL` é "nunca recebi resposta"; `Unknown host` é falha de DNS explícita. A requisição nunca chegou — daí o nginx não ter registro, que estava certo e foi lido como sintoma quando era prova. Rails de pé e sem reinícios também estava certo e era irrelevante.

**A sugestão que estava escrita aqui — checagem periódica de `/api` com alerta — não teria pegado nenhuma das duas.** O serviço estava no ar; quem falhou foi a resolução do nome, fora da nossa máquina.

Estado do DNS hoje: `prs.cortexgen.cloud` → `187.77.20.155`, TTL 14400, respondido pelos **dois** nameservers. Ou seja, falha transitória. O ponto frágil é que `ns1`/`ns2.dns-parking.com` são ambos da Hostinger — dois nomes, um provedor, nenhuma redundância real. Com TTL de 4 h, um resolver do Twilio só consulta de tempos em tempos, e foi numa dessas janelas que caiu.

**Conserto de verdade é fora do código**: DNS secundário em outro provedor (Cloudflare é grátis e aceita ser secundário), ou mover a zona. É mudança de nameserver no registrador — decisão do Paulo, não deploy.

**Conserto dentro do código, entregue** (`82af5ffe4`): a aba Voz lista os alertas da Monitor API do Twilio — método, URL, código com link para a documentação, e a causa. A causa sai do `response_body` de cada alerta, num fetch individual, **e não do `alert_text` da listagem**, que é justamente o que mentiu. Carregado à parte do resto da aba e falhando em silêncio: são N+1 chamadas a uma API de terceiro, e uma tela de configuração não pode esperar nem quebrar por causa disso.

Validado em produção — os dois alertas aparecem com a causa verdadeira:

```
10/08 03:38  11200  Error: Unknown host prs.cortexgen.cloud
10/08 02:29  11200  Error: Total timeout is triggered... responseState=INITIAL
```

Alerta sem corpo de resposta (os de SMS, por exemplo) fica sem causa e a tela esconde o campo, em vez de mostrar uma linha vazia.

**O que falta é seu, não do código:** DNS secundário em outro provedor. Enquanto `ns1` e `ns2.dns-parking.com` forem os dois da Hostinger, uma janela ruim de resolução volta a derrubar chamada — e agora ela aparece no painel em vez de sumir.

### Skills — leia antes de mexer

- **`pipecat`** (`~/.claude/skills/pipecat/`): modelo de turno, a armadilha do mute, tabela sintoma → assinatura no log → causa.
- **`deepgram`** (`~/.claude/skills/deepgram/`): decisão Nova vs Flux, semântica de streaming, telefonia, idioma.

A regra que custou seis ligações está nas duas: **uma mudança por chamada.** As três últimas regressões foram mecanismos adicionados sem validação individual.

**A skill `deepgram` precisa de um parágrafo novo**, que só se aprendeu nesta sessão: o `language` do `STTSettings` **não existe** no caminho Flux (o `_build_query_string` não o lê), e o Flux **alucina uma frase estável sobre quase-silêncio de telefone** — o que faz um turno nascer sem ninguém ter falado. Os dois custaram várias ligações porque nenhum falha de forma visível: um parâmetro parece configurado, e uma transcrição parece um cliente.

### Fase 3 — o que já está em produção

| Peça | Onde |
|---|---|
| `bot_providers.kinds` (`llm`/`stt`/`tts`) + preset ElevenLabs | `db/botlayer/bot_voice.sql`, aplicado |
| Campos de voz na persona + view `bot_persona_resolved` | idem |
| Rota com `answer_mode`/`no_answer_action`/`bot_persona_slug` | migration `20260810000001`, aplicada |
| TwiML `<Connect><Stream>` | `app/controllers/twilio/voice_routing_controller.rb` |
| Endpoint `/voice_agent/config` (Bearer) | `app/controllers/voice_agent/`, `app/services/voice/` |
| Serviço `cortexgen-voice` | `services/cortexgen-voice/`, rodando em `/opt/cortexgen-voice` |
| `wss://prs.cortexgen.cloud/voice-stream` | location no vhost do painel |

**Verificado em 09/08:** health 200; handshake WebSocket real através do nginx OK; endpoint de config responde 401 sem token, 404 em número desconhecido, 422 em rota sem bot. Backup do vhost em `/root/prs.vhost.bak-*`.

### Dois caminhos de transcrição, e por que o direto ganha

| | Deepgram direto | via OpenRouter |
|---|---|---|
| Protocolo | WebSocket, texto chega **enquanto** a pessoa fala | POST de arquivo, só depois do turno fechado |
| Latência | ~200 ms | ~500 ms |
| `api_style` | `deepgram`, modelo `nova-3` | `openai`, modelo `deepgram/nova-3` |
| Conta | própria (o Paulo tem, com saldo) | a mesma chave que já responde mensagens |

Preço igual nos dois (US$0,0043/min). **Usar o direto** — 300 ms é muito quando o alvo é 1,5 s. O OpenRouter fica como caminho de quem não quer criar conta.

O OpenRouter serve Deepgram mesmo, mas **só em lote**: `/api/v1/audio/transcriptions` existe, `/api/v1/realtime` dá 404. Não aparece em `/api/v1/models` porque não é modelo de chat — está em `/api/v1/providers`. (Verificar em `/models` foi um erro meu que o Paulo corrigiu.)

Em qualquer um dos dois o Silero roda local para os turnos. **O Smart Turn v3 foi desligado** — ver "Primeira chamada real" mais abaixo. TTS é ElevenLabs direto, que faz streaming.

**Cartesia (TTS) e Gemini (LLM) não estão ligados** — o Paulo tem as chaves, mas nenhuma persona aponta para elas e cada uma exige uma ramificação no `_stt`/`_tts` do serviço. São ~10 minutos cada quando houver motivo (comparar voz, ou tirar o hop do OpenRouter no LLM).

### O bot passou a ligar, não só a atender (10/08, `0aa0f57ca`)

Validado em chamada real: `started as 'nathan-es-demo'`, 64 s, 6 turnos, mediana **1.867 ms**, contato gravado com o número do prospecto.

Disparo em Settings → Integrations → Twilio → **Voz**, card "Call someone with the bot". Só aparecem números que já têm rota com persona — a chamada de saída reaproveita a rota para achar conta, credencial e configuração.

**A inversão que quebraria em silêncio:** `set_route` resolvia pelo `To`. Numa chamada de saída o `To` é o prospecto e o `From` é o nosso número, então ele procuraria rota para o telefone do cliente e devolveria 404. O endpoint `voice/outgoing` resolve pelo `From`.

**A persona viaja por chamada:** parâmetro do `<Stream>` → serviço de mídia → `/voice_agent/config?persona_slug=`. Sem override, vale a da rota. Foi o que permitiu um roteiro só para quem liga sem tocar no de quem atende.

**`nathan-es-demo`** — 7,5 KB de roteiro contra os 20,6 KB da recepção, porque a conversa é mais estreita: apresenta, confirma se é boa hora, diagnostica em até 3 perguntas, mostra e passa ao consultor. Clona voz, STT, modelo e limiares da persona de entrada. Espera antes de falar em **1.000 ms**, não 2.500: aquela espera existe porque o Twilio descartava o começo do áudio ao receber; em chamada de saída quem atende já disse "alô".

**Armadilha ao clonar persona:** o vínculo com a base de conhecimento vive em `bot_persona_knowledge` e **um `INSERT ... SELECT` não o copia**. A demo nasceu com prompt de 7.483 contra os 24.671 da recepção — sabia menos sobre a empresa justamente na ligação em que o prospecto pergunta o que ela faz. Corrigido para 11.564.

**O que ainda não existe: a fila de quem pediu a ligação.** Hoje o disparo é manual. O fluxo da GHL (botão "receba uma ligação" no widget) precisa de uma página pública, e ela é também **o registro de consentimento** — ver abaixo.

**Identificador de chamada:** sai o número da rota. Para prospecto panamenho, discar do `+1689` chega como internacional desconhecido e derruba a taxa de atendimento. O `+5078389480` (Panamá, já na conta e roteado desde 11/08) resolve isso.

### Inbox de voz nasce na primeira chamada, não ao salvar a rota

`Voice::CallReportService#inbox` faz `find_by(id: route.voice_inbox_id) || create_inbox`. Salvar a rota **não** cria inbox: ela aparece como `Voz — <número>` quando a primeira chamada é registrada. É de propósito (nada de inbox vazia), mas invisível na tela — a pergunta "e a inbox dele?" já apareceu uma vez.

### Nomes de inbox seguem "Canal — identificador" (11/08)

As inboxes antigas não tinham padrão e duas eram indistinguíveis (`PRS Brands` para Messenger e `prsbrands` para Instagram). Renomeadas:

```
2 WhatsApp — Com Cortex   8 Instagram — prsbrands   9 Messenger — PRS Brands
10 Website — PRS Brands  14 WhatsApp — Numero2     15 SMS — +16893539100
16 Voz — +16893539100    17 E-mail — CortexGen
```

O canal vem primeiro porque é o que o agente precisa saber antes do resto. A inbox 10 foi renomeada depois disso e hoje se chama **`CortexGen Chat`** — fora do padrão, e é a do widget que está no ar. Depois de 11/08 a conta 1 ganhou `18 Voz — +5078389480` e `19 Voz — +551150289898`. A conta 2 tem `20 Voz — +558523981900`, `22 WhatsApp — teste1`, `23 Site — Da Gente` — e `21 Atendimento DaGente`, o widget, que **foge do padrão** e vale renomear para `Website — Da Gente` quando alguém passar por ali.

### Fase 3c entregue — a chamada vira conversa, contato e lead

Ao desligar, o serviço de mídia manda transcrição, duração e os dados do lead para `/voice_agent/calls`. O Chatwoot cria conversa numa inbox **própria de voz** (`Voz — <número>`, tipo `Channel::Api`, gravada em `twilio_voice_routes.voice_inbox_id`).

**Por que inbox separada e não a de SMS do mesmo número:** naquela, mensagem de saída é enviada de verdade pelo Twilio — devolver ao cliente a transcrição da própria ligação por SMS seria um acidente caro. Inbox de API não envia nada sozinha.

**Enriquecimento do contato** (mesma chamada de IA que faz o resumo, um request só): nome, e-mail, empresa e cidade saem da conversa; **país sai do número** via `TelephoneNumber` (`country_id` → ISO); WhatsApp assume o número de origem salvo se ditarem outro. Convenção do Chatwoot: `additional_attributes['country']` guarda o ISO e o `Contacts::SyncAttributes` espelha para `country_code`; `['city']` vira `location`; o contato passa a `lead`.

**Cidade NÃO sai do telefone, de propósito.** O gem não fornece, e número diz onde a linha foi habilitada — em celular nem isso. O prompt de extração manda explicitamente não adivinhar cidade pelo país. Preencher por DDD daria dado errado com cara de certo.

### Paciência ao soletrar — o que quebrou e como

Numa chamada real quem ligou soletrou "arrowgen" e o bot respondeu na quarta letra:

```
[incoming] Yo voy a deletrear
[incoming] a r r o
[outgoing] Gracias,          ← cortou aqui
```

Silêncio sozinho não distingue fim de frase de pausa entre duas letras. Agora quem decide é o modelo: o Pipecat pede que ele marque cada resposta como turno completo ou incompleto (`FilterIncompleteUserTurnStrategies`), e só o completo libera a fala. **Sai de graça** — é a mesma resposta que já estava sendo gerada. As instruções padrão do Pipecat cobrem ser cortado e pensar alto; o caso de ditado foi acrescentado por cima.

Interruptor visível na persona (`voice_wait_for_complete_turn`, padrão ligado) porque o mecanismo depende de o modelo obedecer a um formato — modelo pequeno que ignorar deixaria o bot mudo, que é exatamente a falha do Smart Turn.

**Saudação cortada — a tentativa de conserto foi pior que o defeito.** Pus `MuteUntilFirstBotCompleteUserMuteStrategy` para a abertura não ser cortada por um "alô?", e ela **matou uma chamada em 62 s de silêncio**: a abertura pergunta o nome, quem ligou respondeu no meio, o mute descartou os quadros de VAD e nenhum turno chegou a começar — com a transcrição já parada no contexto. Removido em `92b66a28f`. Detalhe do mecanismo na skill `pipecat`, seção 2.

### Correção: a latência do LLM varia muito mais do que a primeira medição sugeria

Medi 0,103 s numa chamada e registrei como típico. Nas seguintes: **0,575 s, 1,132 s e 1,341 s**. O `gpt-4.1` é irregular, então trocar para `gpt-4.1-mini` ajuda latência **e** custo (5× mais barato: US$0,024 vs US$0,120 numa chamada de 3 min). Benchmark completo em https://claude.ai/code/artifact/bb9db886-7084-4e34-882d-3a9338cc8b73

### Ainda aberto na Fase 3/4

- ~~Fallback de LLM na chamada~~ — **entregue** em `64fda3a37`. Principal e reserva vão no mesmo request (`extra.models`), o roteador do OpenRouter desce para o segundo sem nova ida à rede; `retry_on_timeout=True` com 6 s cobre modelo que emudece. Reserva em **fornecedor diferente** é recusada com aviso no log, não fingida — trocar de endpoint no meio do stream é outro problema, e a persona já oferece "same as primary" como padrão. Hoje: `openai/gpt-4.1-mini` → `deepseek/deepseek-v4-flash-0731`.
- ~~Termos que não interrompem~~ — **entregue** como `voice_interrupt_min_words` (padrão **0 = desligado**). Com 2, um "ajá" de cortesia não cala o bot — mas um "para!" de uma palavra também não. Trade-off escrito no campo; vale testar os dois numa chamada real.
- **Aviso de alterações não salvas no editor de persona**: medi que os saves funcionam (três PATCH, tamanhos crescentes, 200 OK), mas sair pela seta ← descarta tudo em silêncio.
- ~~Medição por chamada~~ — **entregue** em `008ad8836`. Cada chamada guarda em `twilio_voice_calls.metrics`: turnos, tokens, caracteres falados, segundos transcritos e a **latência sentida** (do fim da fala de quem ligou à primeira sílaba do bot), como mediana + pior caso. Aparece na aba Voz por chamada. Coletado por um `BaseObserver` próprio + o `UserBotLatencyObserver` do Pipecat.
- **Custo em dólar**: falta uma tarifa por fornecedor. Não inventei preço porque a **ElevenLabs cobra por plano**, não por caractere a preço fixo — um número confiante e errado na tela é pior que campo vazio. Desenho sugerido: colunas de tarifa em `bot_providers`, com os presets já preenchidos pelas tabelas públicas (Deepgram US$0,0043/min, OpenRouter por modelo em `/api/v1/models`, Twilio ~US$0,0085/min).
- **Pronúncia**: a ElevenLabs lê "PRS" como "PE, r, essi". Contornado escrevendo foneticamente na frase de abertura; dicionário de pronúncia resolveria de verdade.
- **Concorrência**: quantas chamadas simultâneas a VPS aguenta é medição, não estimativa.
- Chamada **saindo** do softphone segue sem funcionar (`voice_url` do domínio SIP é nil) — lacuna da Fase 2.

### Primeira chamada real (09/08, 22:25) — o que ela ensinou

O bot atendeu, se apresentou, perguntou o nome, respondeu "Gracias, Pablo" — e depois **emudeceu**. Diagnóstico pelos logs do `cortexgen-voice`:

O Pipecat fecha o turno de quem fala com o **Smart Turn**, um modelo semântico que julga se a frase acabou. Em espanhol ao telefone ele devolvia `INCOMPLETE` sempre, então o turno só fechava no **timeout de 5 s**. Cinco segundos de nada parecem queda de ligação, o cliente fala de novo, e essa fala **interrompe** a resposta que estava chegando. O log pega no flagrante: `broadcasting interruption` às 46.049 e `OpenAILLMService TTFB: 0.103s` às 46.052 — a resposta perdeu por 3 ms.

Corrigido em `7f7b9ecc0`: fim de turno por **silêncio** (`SpeechTimeoutUserTurnStopStrategy`), que é o que o campo "End of turn (ms)" da persona sempre prometeu controlar e não controlava. Rede de segurança de 5 s → 2 s.

**Latência medida na chamada real** (do fim da fala ao primeiro áudio, ≈ 1,1 s — dentro do alvo de 1,5 s):

| Etapa | Medido |
|---|---|
| Deepgram (inclui os 600 ms de endpointing configurados) | 0,67–0,72 s |
| LLM (gpt-4.1, prompt de 21 KB) | **0,103 s** |
| ElevenLabs até o primeiro áudio | 0,33 s |

**Correção de uma coisa que eu disse antes:** avisei que o prompt de 21 KB seria latência audível. **Não foi** — o modelo respondeu em 100 ms. O maior componente é o endpointing de 600 ms, que é ajustável na persona. Encurtar o prompt continua valendo por qualidade de conversa (respostas curtas e faladas), não por latência.

### Descoberta: Deepgram **Flux** substituiria toda a pilha de turnos

A Deepgram tem duas famílias, e estamos na errada para o nosso caso:

| | Nova (`/v1/listen`) — o que usamos | Flux (`/v2/listen`) |
|---|---|---|
| Para quê | legendas, gravações, transcrição geral | **agentes de voz conversacionais** |
| Detecção de turno | **nossa**, manual | **embutida** (EOT, EagerEOT) |
| Multilíngue | `language="multi"` | `flux-general-multi` + `language_hints` atualizáveis no meio da chamada |

**O Pipecat 1.7 já suporta** — `pipecat.services.deepgram.flux.stt.DeepgramFluxSTTService`, com eventos `on_start_of_turn`, `on_eager_end_of_turn`, `on_end_of_turn` e `on_turn_resumed`.

Resolveria de uma vez três problemas que venho remendando: a máquina de turnos frágil (passaria para a camada que ouve o áudio, que é onde a informação está), a mistura espanhol/português, e o "turno especulativo" do benchmark da ElevenLabs — que no Flux é o `EagerEOT`, de fábrica.

**Não migrei** porque seria a maior mudança até agora e a regra de uma mudança por chamada vale mais depois de seis regressões. É a próxima decisão de arquitetura a tomar, não um ajuste.

### Skill `pipecat` — leia antes de mexer no serviço de voz

`~/.claude/skills/pipecat/SKILL.md`. Carrega sozinha quando o assunto é Pipecat ou um sintoma de chamada. Contém o modelo de turno (início e fim são estratégias independentes; `None` aplica o padrão, não desliga), a armadilha do mute que mata a chamada em silêncio, a configuração de referência para telefonia, o que mudou de lugar na 1.7, e uma **tabela sintoma → assinatura no log → causa** para diagnosticar em segundos.

A regra que custou seis ligações está lá: **uma mudança por chamada.**

### Skill `deepgram`

`~/.claude/skills/deepgram/SKILL.md`. Decisão Nova vs Flux, semântica de `endpointing` / `utterance_end_ms` / `interim_results` (e por que ruído de linha trava o primeiro — confirmado pela documentação da Deepgram), configuração de telefonia, idioma e troca de idioma, tabela de diagnóstico. Skills oficiais da Deepgram em <https://github.com/deepgram/skills>.

### Armadilha: `extra` do Pipecat vira kwargs do SDK, não corpo do request

O fallback de LLM foi entregue mandando `models` em `OpenAILLMSettings.extra`. O Pipecat faz `params.update(settings.extra)` e passa tudo para `AsyncCompletions.create(**params)` — o SDK da OpenAI **não conhece `models`** e recusou toda chamada com `unexpected keyword argument`. O bot falava a saudação (que não passa pelo modelo) e emudecia. O lugar certo é **`extra_body`**, a porta do SDK para campos que só o fornecedor entende.

Na mesma leva, `STTUsageMetricsData.value` é um **objeto** `STTUsage(audio_seconds=…)`, enquanto o do TTS é um `int` puro — somar o objeto como número estourava em toda chamada.

Nenhum dos dois falhava antes de uma chamada real. O `smoke.py` agora confere os kwargs **contra a assinatura real do `AsyncCompletions.create`** e alimenta o coletor com objetos de métrica de verdade; ambos foram verificados rejeitando as versões que subiram.

### Armadilha: a API do Pipecat muda entre versões menores

Na 1.7 o `allow_interruptions` do `PipelineParams` **não existe mais** (virou `user_mute_strategies` no agregador), o VAD saiu do transport e virou `VADProcessor` no pipeline, e `model=`/`voice_id=` viraram `settings=Settings(...)`. Nada disso quebra no build — só na chamada. Por isso o `smoke.py` vai dentro da imagem e **roda antes de subir**: instancia cada peça com config falsa, sem gastar crédito. Foi ele que pegou os três.

---

Plano completo em `PLAN-TWILIO-VOZ.md`.

### O que já funciona em produção

| Fase | Commit | Entrega |
|---|---|---|
| 0 | `d6c5771c3` | Twilio conectado **por conta** (Settings → Integrations → Twilio), validado contra a API antes de gravar, token criptografado. Números listados com as capabilities de cada um |
| 1 | `19c59c3d5` | Inbox de SMS em 1 clique, com o `sms_url` gravado no número pela API. Paginação (`page_size: 25`) + busca do lado do Twilio. Aviso de A2P 10DLC em `+1` |
| 2 | `fa80e1eda` | Voz entrando: rotas próprias, domínio SIP e credenciais provisionados pelo painel, roteamento por número, transbordo para mensagem quando não atendem |

**Provado com tráfego real em 09/08:**
- SMS entrando e saindo no **+16893539100** (inbox 15, conversa 17, saída `delivered` — o A2P não barrou)
- Chamada de voz entrando, tocando no Zoiper e **atendida** (`TwilioVoiceCall` com `status=completed`, `+16893291777 → +16893539100`)
- Domínio SIP **`cortexgen-prs.sip.twilio.com`** criado pelo painel, credencial `paulo` registrada no Zoiper

**Migrations aplicadas:** `20260809000001` (`twilio_credentials`), `20260809000002` (`twilio_voice_routes`, `twilio_voice_calls`).
**Flags ligadas na conta 1:** `whatsapp_sessions`, `bot_personas`, `ai_providers`, `twilio_integration`.

### Lacunas conhecidas, por ordem de importância

1. **Chamada SAINDO do softphone não funciona** — o domínio SIP está com `voice_url = nil`, então o Twilio não sabe o que fazer com uma chamada originada no Zoiper e devolve ocupado. Não foi construído porque a Fase 2 era receber. Exige decidir qual número aparece como identificador, restrição de destino e registro da chamada.
2. ~~`bot_providers` só tem provedores de LLM~~ — **resolvido na Fase 3** com `kinds text[]` (array, não coluna singular: a mesma conta de OpenAI serve os três e a chave é o que não se quer duplicar). Ver "Dois caminhos de transcrição" no topo.
3. **Paginação/busca só na aba Números**; a aba Voz lista tudo direto.
4. **Assistente de escrita CortexGen AI nunca foi testado de verdade** — chave OpenAI gravada, endpoint vazio (= `api.openai.com`). Abrir uma conversa e usar reescrever/resumir. Se falhar, os erros úteis são `captain.api_key_missing` e qualquer coisa do `Llm::FeatureRouter` (modelo fora do catálogo de `config/llm.yml`).
5. Aba Channels com a coluna Agent bot: ligar o switch e conferir em Settings → Inboxes → Bot Configuration que o vínculo nasceu sozinho.
6. Widget real no site; handoff do bot ("quiero hablar con un consultor" deve virar `open`); multi-turno com histórico no prompt.
7. Limpar contatos/conversas de teste e as inboxes duplicadas de WhatsApp (#12, #13, #14).

### Os 9 outros números do Twilio são da GoHighLevel

Só o **+16893539100** migrou para cá. Os demais seguem apontados para `msgsndr.com` / `leadconnectorhq.com`, e **4 dos 6 domínios SIP servem a GHL em produção**. O painel os lista como externos e sem botão de editar, de propósito: reapontar um deles derrubaria a telefonia de um cliente. Não mudar isso sem pedir.

## Protocolo de deploy (custou duas quedas em 09/08)

1. `git push` do Mac
2. `git pull` na VPS
3. `docker build -t cortexgen-chat:test`
4. **Teste de fumaça: SUBIR a imagem `:test` numa porta livre e exigir HTTP 200.** Não é opcional e não é o mesmo que o passo 3 — ver abaixo
5. Só então `docker build -t cortexgen-chat:v1` + `docker compose up -d --force-recreate rails sidekiq`
6. **Esperar em loop até `/api` devolver 200** (~24 s). **Nunca** encadear `docker compose exec` logo após o `up -d`
7. `docker compose ps` + as 3 rotas; rollback para o commit anterior se o passo 6 estourar

### Por que o passo 4 existe

**`docker build` compila os assets e carrega o código, mas não sobe o Rails.** Erros de boot — callback inexistente, initializer quebrado, constante ausente — passam pelo build e só aparecem quando o servidor monta. Foi assim que `skip_before_action :verify_authenticity_token` (callback que o `ApplicationController` do Chatwoot não instala) passou no `:test` verde e deixou o site em crash-loop por 4 minutos.

```bash
docker run -d --name cgtest --network cortexgen-chat_default --env-file .env \
  -e RAILS_ENV=production -e NODE_ENV=production -e INSTALLATION_ENV=docker \
  -p 127.0.0.1:3099:3000 --entrypoint bundle cortexgen-chat:test exec rails s -p 3000 -b 0.0.0.0
sleep 25
curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Forwarded-Proto: https' -H 'Host: prs.cortexgen.cloud' http://127.0.0.1:3099/api
docker rm -f cgtest
```

Sem `X-Forwarded-Proto: https` a resposta é 301, não 200 — não confundir com falha.

### Migrations não rodam sozinhas

O `docker/entrypoints/rails.sh` **não** executa `db:migrate`. Aplicar à mão antes de recriar os containers:

```bash
docker run --rm --network cortexgen-chat_default --env-file .env -e RAILS_ENV=production \
  cortexgen-chat:test bundle exec rails db:migrate
```

### O rollback custa um rebuild

A tag `:v1` é sobrescrita a cada deploy, então voltar exige `git checkout <sha>` + build. Vale migrar para tags versionadas (`:v1-<sha>`) — ainda não feito.

### Nenhum lint roda no checkout do Mac

Sem `node_modules` e sem rbenv, `rubocop` e `eslint` nunca rodam localmente. O `docker build` é o único gate de sintaxe, e o passo 4 é o único gate de boot.

### Acesso do Claude

`.claude/settings.local.json` (fora do git) libera `git push` e `ssh` para `187.77.20.155` com a chave `id_ed25519_cortexgen`. O Claude executa push, deploy e testes direto.

## Bugs corrigidos (não repetir)

### Guard descartava tudo (sessão 07/08)
O Chatwoot atribui a conversa **ao próprio agent bot**, então o payload chega com `meta.assignee_type = "AgentBot"`. O filtro "humano já assumiu" lia qualquer `assignee` preenchido e abortava — o Nathan se filtrava. Correção: `if (meta.assignee_type === 'User') return [];`

### Historico com 401 "Authorization failed" (sessão 08/08)
Token de **Agent Bot só serve para uma whitelist fechada** de endpoints — `app/controllers/concerns/access_token_auth_helper.rb` (`BOT_ACCESSIBLE_ENDPOINTS`): em `conversations` só `show/toggle_status/toggle_typing_status/toggle_priority/create/update/custom_attributes`; em `messages` só `create`. **`messages#index` (o GET do Historico) não está na lista** → 401. E `conversations#show` não substitui: devolve só a última mensagem.
Correção: nó **Historico** usa credencial `Chat User Token` (Header Auth `api_access_token` com token de **User** do painel, Profile Settings → Access Token). **Responde** e **Handoff** continuam com o token do bot (`CortexGen Chat Bot (api_access_token)`) — é isso que assina a resposta como Nathan.

---

## Estado dos subsistemas

### Infra ✅
- VPS srv1365122 (`187.77.20.155`), stack em `/opt/cortexgen-chat` (imagem `cortexgen-chat:v1`)
- rails (porta 3021) + sidekiq + postgres pgvector + redis — isolado do Chatwoot antigo (`chat.cortexgen.cloud`, porta 3020)
- nginx + Let's Encrypt (renova sozinho, expira 2026-11-05)
- Fork `prsbrands/chatwoot`, branch `feature/cortexgen-whitelabel`. Produção e GitHub sincronizados em `821c8ec09` (conferido em 15/08)
- Edição Community/MIT: `DISABLE_ENTERPRISE=1`, `DISABLE_TELEMETRY=true`
- Conta: **PRS Global Business** (id 1), flag `disable_branding` ativa

### Canais ✅
| Inbox | Canal | Como conecta |
|---|---|---|
| 2 — WA Com Cortex | WhatsApp (API) | OpenWA `com.cortexgen.cloud`, plugin chatwoot-adapter instância `teste`, ingress `/api/ingress/chatwoot-adapter/teste/chatwoot` |
| 8 — prsbrands | Instagram DM | App Meta **CortexComm** (1012302828635509), webhook `/webhooks/instagram` |
| 9 — PRS Brands | Facebook Messenger | Mesmo app, webhook `/bot`, Login Config `1809600620222184` |
| 10 — Website | Widget do site | Token `MrtKJhxPBc9DgjjCaU4so6o1`, cor #7C3AED |

- Instâncias do chatwoot-adapter **só podem ser criadas via API REST** (o painel gera um secret que nunca bate). Receita: README em github.com/rmyndharis/OpenWA-plugins/tree/main/chatwoot-adapter
- App Review da Meta não foi feito — funciona para as contas próprias (admin do app). Só necessário se terceiros forem conectar.

### Camada de bots — Supabase self-hosted ✅
`supabase.cortexgen.cloud` (container `supabase-db`), schema `public`, prefixo `bot_`.

| Objeto | Papel |
|---|---|
| `bot_personas` | Identidade, `system_prompt`, provider, `model`, `fallback_model`, temperature, `max_tokens`, `handoff_rules` |
| `bot_channel_routes` | inbox → persona; `is_active` liga/desliga o bot no canal; `overrides` jsonb; `channel_kind` text\|voice |
| `bot_knowledge_docs` / `bot_persona_knowledge` | Base de conhecimento; `is_global` entra no prompt de todas as personas |
| `bot_conversation_state` | Memória curta por conversa (ainda **não usada** pelo workflow) |
| `bot_interactions` | Log por chamada: modelo, tokens, latência, status |
| `bot_route_resolved` (view) | O que o n8n consome: 1 GET por inbox, devolve `composed_prompt` = persona + conhecimento |

- **RLS ligado sem policies**: anon key retorna `[]`, só a `service_role` lê. View com `security_invoker = true`. Chaves em `/opt/supabase/.env`.
- Personas ativas: **`nathan-website`** (inbox 10), **`nathan-social-dm`** (inboxes 8/9) e **`nathan-whatsapp`** (inbox 2) — as duas últimas são clones do nathan-website com etiqueta do canal, criadas 2026-08-08 via `persona_nathan_social.sql` / `persona_nathan_whatsapp.sql` (scratchpad). Todas as 4 rotas ativas.
- Persona `atendimento-prs` está **obsoleta, não usar como está**: aponta `provider: anthropic` / `claude-sonnet-5` — o workflow chama OpenRouter e esse ID de modelo quebraria na chamada. Se reaproveitar (ex.: WhatsApp), trocar para openrouter + modelo válido ou clonar de um dos Nathans.
- Base `prs-brands-core` (6,6 KB, global) vinda de `md/prs-brands-knowledge-base.md`. Decisões editoriais: escrita em espanhol; seção 10 (notas internas) excluída; seção 8 virou **guardrails** — proibido citar percentuais de resultado, inventar preço/prazo ou confirmar agenda.
- Prompt final do Nathan ≈ 11,6 KB (~3k tokens).
- SQL versionável no scratchpad: `bot_layer.sql`, `bot_seed.sql`, `bot_knowledge.sql`, `kb_prsbrands.sql`, `persona_nathan.sql`, `openrouter.sql`. **Vale mover para o repo** se a camada virar permanente.

### O webhook do bot passou a exigir assinatura (10/08)

Era endpoint aberto: quem soubesse a URL injetava mensagem, fazia o bot responder e gastava crédito de LLM escrevendo em conversa de cliente. O Chatwoot **já assinava** todo payload — ninguém conferia. Código versionado em `ops/n8n/guard.js`.

Esquema, de `lib/webhooks/trigger.rb`: `X-Chatwoot-Signature: sha256=HMAC_SHA256(secret, "<X-Chatwoot-Timestamp>.<corpo cru>")`, com o secret vindo de `AgentBot#secret`.

**O corpo cru é o problema, e a implementação óbvia estaria errada.** O n8n entrega o JSON já parseado, e `JSON.stringify` **não** reproduz o que o Rails mandou: o ActiveSupport escapa `<`, `>` e `&` como `<`, `>`, `&`. Medido lado a lado:

```
ruby: "<script> ... & entidades"      js: "<script> ... & entidades"
ruby: "numeros":1.0                                  js: "numeros":1
ruby: 12345678901234567890                           js: 12345678901234567000
```

Acentos e emoji passam idênticos. Mas com o stringify puro, **toda mensagem contendo `&` ou HTML seria recusada** — "R&D", "Ben & Jerry", e a inbox de e-mail inteira, que entrega HTML. Seria bot mudo só para alguns clientes, sem erro visível. O Guard reaplica o escaping do Rails antes de calcular o HMAC; provado contra assinaturas geradas pelo próprio Rails, inclusive um payload com `R&D <b>ola</b> — Ben & Jerry`.

Floats e inteiros gigantes continuam divergindo e **não** são tratados: nenhum payload real de agent bot tem float, e os ids cabem no range seguro do JS. Se um dia entrar um float no payload, o sintoma será recusa de mensagem legítima.

**O Guard falha alto, de propósito.** `return []` deixaria a execução verde e a mensagem sumindo — o modo de falha que mais custou neste projeto. Assinatura ausente, inválida ou com mais de 5 minutos levanta erro, e a execução aparece vermelha na lista do n8n.

**Duas variáveis de ambiente que o n8n exige, e nenhuma falha de forma óbvia:**

| variável | por quê |
|---|---|
| `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` | acesso a `$env` em Code node é bloqueado por padrão — o código lê `process.env.N8N_BLOCK_ENV_ACCESS_IN_NODE !== 'false'`, então só a string `false` libera |
| `NODE_FUNCTION_ALLOW_BUILTIN=crypto` | sem ela, `require('crypto')` levanta **`Module 'crypto' is disallowed`** dentro do sandbox |

A segunda custou uma janela de bot mudo: importei o Guard, a mensagem legítima falhou, e só o `execution_data` no sqlite dizia o motivo. **Depois de importar, mande uma mensagem real e confira o status da execução** — 200 no webhook não significa nada, porque o `responseMode: onReceived` responde antes de processar.

O segredo ia para o n8n por `CHATWOOT_WEBHOOK_SECRET` no `.env` de `/docker/n8n-y4jd/`, copiado direto do banco do Chatwoot sem passar por tela nem histórico. **Isso valeu até 13/08 e não vale mais** — um segredo fixo é o de um bot só, e toda conta nova tem o seu: o Guard passou a resolver o secret por conta no Supabase (ver "A segunda conta em produção" no topo). O que continua valendo daqui é o mecanismo da assinatura e o escaping do Rails, que não mudaram.

Provado em produção: execuções 13455–13457 `success` com mensagens legítimas (o bot respondeu), execução 13458 `error` com POST forjado e **nenhuma resposta gerada**.

### Workflow n8n ✅ (publicado e testado, 3,9 s de latência)
`pd5V9pdaldRLUu4C` · webhook `https://n8n.cortexgen.cloud/webhook/cortexgen-bot`

```
Webhook → Guard → Persona (Supabase) → Historico (10 últimas msgs)
  → MontaPrompt → LLM (OpenRouter, reasoning off) → Interpreta → Responde
  → Log (bot_interactions) → PrecisaHandoff → Handoff (toggle_status: open)
```

- Credenciais por nó: **Persona/Log** `Supabase account 2` · **LLM** `OpenRouter account 2`. **`Historico`, `Responde` e `Handoff` não têm mais credencial fixa** — desde 13/08 mandam o header `api_access_token` por expressão, com o token que o Guard resolveu para aquela conta (ver "A segunda conta em produção" no topo). Este workflow atende **todas** as contas.
- **Provider OpenRouter**, formato OpenAI-compat. Primário `deepseek/deepseek-v4-flash-0731` ($0.09/$0.18 por M, 1.05M ctx), fallback `tencent/hy3` ($0.13/$0.53, 262K) via o array `models` — o roteador cai no segundo na mesma chamada. Trocar de modelo = UPDATE em `bot_personas`, sem mexer no workflow.
- Merge fields do GHL (`{{contact.first_name}}`, `{{contact.email}}`, `{{contact.call_summary}}`) são substituídos no `MontaPrompt` pelos dados do contato Chatwoot. O atributo `call_summary` existe nos contatos.
- Handoff **determinístico** (keywords + `max_turns` + `content_filter`), não depende do modelo decidir.
- Webhook responde 200 imediato (`responseMode: onReceived`) — senão o Chatwoot considera falha e reenvia enquanto o modelo pensa.
- Erros do OpenRouter vêm no corpo com HTTP 200; `Interpreta` detecta e falha explicitamente.

### Operação do bot no painel do Chatwoot

- **Onde ver as conversas do bot**: elas ficam com status **Pending** (o painel abre no filtro Open por padrão — trocar o filtro de status no topo da lista, ou usar "All Conversations"). Quando o handoff dispara, o workflow faz `toggle_status: open` e a conversa entra na fila Open normal — esse é o sinal para humano assumir.
- **Humano pode intervir a qualquer momento**: se a conversa for atribuída a um User, o Guard se retira sozinho (`assignee_type === 'User'`).
- **Atribuição do bot é por inbox, em DUAS camadas que precisam concordar**:
  1. Chatwoot: Settings → Inboxes → *inbox* → **Bot Configuration** → selecionar "Nathan" (é o que faz o webhook disparar). Hoje: só inbox 10.
  2. Supabase: rota em `bot_channel_routes` com `is_active = true` (é o que dá persona ao `MontaPrompt`). Hoje: só inbox 10; rotas 2/8/9 inativas.
  Só Chatwoot ligado → Guard passa mas MontaPrompt descarta (sem persona). Só Supabase → webhook nem dispara.
- **"Give the team a way to reach you." / "Get notified by email" NÃO são do bot** — são o *email collect box* do widget (`inbox.enable_email_collect`, template disparado por `app/services/message_templates/hook_execution_service.rb` quando o contato não tem e-mail). O visitante via como cartão pedindo e-mail. **Desligado na inbox 10 em 2026-08-08** (`enable_email_collect: false`) — o prompt do Nathan já pede e-mail no momento certo da conversa. Religar (se quiser): Settings → Inboxes → Website — PRS Brands → Configuration → "Enable email collect box". Esses templates também disparam o webhook do bot, mas o Guard os descarta (`message_type !== 'incoming'`).

---

## Armadilhas descobertas (custaram tempo)

- **SDK do n8n MCP**: parâmetros só persistem em `config: { parameters: {...} }`. Usar `config: {...}` direto ou `parameters: {...}` passa na validação (`valid: true`) e grava o nó **vazio**, sem erro. Conferir sempre lendo `workflow_entity.nodes` no sqlite de `n8n-y4jd-n8n-1` (`/home/node/.n8n/database.sqlite`) — o mesmo banco serve para ler execuções (`execution_entity` / `execution_data`, formato de string-table: valores numéricos são índices no array).
- **`update_workflow` do n8n MCP APAGA as credenciais** dos nós HTTP (e regenera os IDs dos nós) — o campo `credentials` no código SDK é descartado silenciosamente. Receita para editar o workflow do bot sem clique manual: (1) `docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json`; (2) editar o JSON (nós, e reinjetar `credentials: {tipo: {id, name}}` — ids na tabela `credentials_entity`); (3) `n8n import:workflow --input=...` (desativa o workflow!); (4) publicar de novo (MCP `publish_workflow` reativa). Sintaxe do SDK que valida: nós como objetos `{type, version, name, config:{parameters}}` e `wf.add(a).to(b).to(c)`.
- **Cópia do sqlite do n8n para debug**: copiar também o `-wal` (`database.sqlite-wal`), senão a cópia fica minutos atrasada e execuções recentes "não existem".
- **Claude Sonnet 5 / Opus 5** (se um dia voltar para a Anthropic direto): rejeitam `temperature`/`top_p`/`top_k` com **HTTP 400**, e o *adaptive thinking* é o padrão quando `thinking` é omitido — com `max_tokens` limitando pensamento + resposta juntos. Mandar `thinking: {type:'disabled'}` ou dar folga no `max_tokens`.
- **Endpoint público de widget**: `/public/api/v1/inboxes/{token}/...` é para inbox do tipo **API**, não para widget de site. Para testar o widget, injetar a mensagem via `rails runner` (receita no topo).

---

## Pendências

### 1. E-mail — RESOLVIDO em 2026-08-10 com relay Resend

**O bloqueio nunca foi de SMTP em geral — era da rota até o GreenGeeks.** Da mesma VPS, `smtp.resend.com` responde nas portas 465, 587, 2465, 2587 **e 25**, e `api.resend.com` devolve 401 (alcançável, só sem credencial). A pendência mais antiga do projeto caiu por um caminho que sempre esteve livre; o diagnóstico anterior generalizou um bloqueio específico.

Config ativa no `.env` (backup em `.env.bak-resend-*`), aplicada pelo `/opt/cortexgen-chat/set-resend.sh`, que pede a chave sem exibi-la:

```
SMTP_ADDRESS=smtp.resend.com   SMTP_PORT=465   SMTP_USERNAME=resend
SMTP_AUTHENTICATION=plain      SMTP_TLS=true   SMTP_DOMAIN=cortexgen.cloud
MAILER_SENDER_EMAIL=CortexGen Chat <no-reply@cortexgen.cloud>
```

**O remetente mudou de `@prsbrands.com` para `@cortexgen.cloud` de propósito.** Quem tem DKIM verificado no Resend é o `cortexgen.cloud`; enviar como `@prsbrands.com` por ali seria remetente sem assinatura — caminho curto para spam num e-mail de reset de senha. Os três registros do Resend estão publicados: `MX send.cortexgen.cloud → feedback-smtp.us-east-1.amazonses.com`, `TXT send.cortexgen.cloud → v=spf1 include:amazonses.com ~all`, e o DKIM em `resend._domainkey.cortexgen.cloud`. O DMARC do domínio está em `p=none` e alinha pelo DKIM.

**Provado com dois envios reais:** um `ActionMailer` direto (`ENVIADO ok`) e um reset de senha de verdade pela fila, entregue pelo Sidekiq em 470 ms sem erro. Atenção ao que o reset testou: `User.find(1)` nesta instalação devolve um **SuperAdmin** (`technology@prsbrands.com`), então o link recebido é o do painel Super Admin. O caminho de e-mail é o mesmo do convite de agente, que ainda não foi exercitado com um agente novo.

**A chave é restrita a envio** (`restricted_api_key`): a API de domínios devolve 401. Bom para segurança, e significa que conferir verificação de domínio pelo código não é possível — o teste é enviar.

**Entrada de e-mail: RESOLVIDA no mesmo dia, por Mailgun.** Ver a seção seguinte. (O `MX` de `prsbrands.com` continua no GreenGeeks e fora de alcance — quem recebe agora é o `cortexgen.cloud`.)

### 1c. Entrada de e-mail — Mailgun → ActionMailbox (10/08)

Cadeia completa, provada ponta a ponta: `MX → Mailgun → Route → POST no ingress (204) → conversa 63 na inbox 17`, com o contato criado a partir do remetente.

| peça | valor |
|---|---|
| MX de `cortexgen.cloud` | `mxa`/`mxb.mailgun.org` (região **US**) |
| Route no Mailgun | `match_recipient(".*@cortexgen.cloud")` → `forward(<ingress>)` + `store()` |
| ingress | `https://prs.cortexgen.cloud/rails/action_mailbox/mailgun/inbound_emails/mime` |
| inbox | **17 — "E-mail — CortexGen"**, casando `contato@cortexgen.cloud` |
| env | `RAILS_INBOUND_EMAIL_SERVICE=mailgun`, `MAILGUN_INGRESS_SIGNING_KEY`, `MAILER_INBOUND_EMAIL_DOMAIN=cortexgen.cloud` |

Script: `ops/set-mailgun-inbound.sh` (pede a signing key sem exibi-la).

**A URL do ingress termina em `/mime`**, não em `/inbound_emails` — o caminho "óbvio" devolve 404. Vale conferir na tabela de rotas antes de configurar qualquer provedor: `Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(/action_mailbox/)`.

**O ingress estava desligado sem dar erro.** O `.env` trazia `RAILS_INBOUND_EMAIL_SERVICE=` **vazio**, e `ENV.fetch('RAILS_INBOUND_EMAIL_SERVICE', 'relay')` devolve string vazia quando a variável existe em branco — o Rails ficava com `ingress = :""`, sem ingress ativo e sem reclamar. Vazio não é ausente, e o default nunca entrou.

**A sonda que diagnostica em segundos**, sem depender de propagação nem de conta de terceiro — pergunta ao MX do Mailgun se ele aceita o destinatário:

```python
import smtplib
s = smtplib.SMTP("mxa.mailgun.org", 25, timeout=20); s.ehlo()
s.docmd("MAIL FROM:<teste@prs.cortexgen.cloud>")
print(s.docmd("RCPT TO:<contato@cortexgen.cloud>"))
```

As respostas se distinguem e valem uma tabela:

| resposta | significa |
|---|---|
| `550 5.7.1 Relaying denied` | o domínio **não está** na conta Mailgun |
| `550 5.0.1 Recipient rejected` | domínio registrado, **falta a Route** |
| `250 Recipient address accepted` | pronto para receber |

**Erro de sequência que custou um endereço:** mandei o e-mail de teste **antes** de a Route existir, levou bounce `550`, e o Resend pôs `contato@cortexgen.cloud` na lista de supressão. Depois disso, mensagem enviada pelo Resend para esse endereço é aceita pela API e **não é entregue** — o que sumiu foi só o teste, mas o endereço segue suprimido até alguém limpar no dashboard (a chave é restrita a envio, então não dá pela API). **Sonde com o `RCPT TO` antes de enviar qualquer coisa.**

`store()` junto do `forward()` na Route é rede de segurança: POST que falhar deixa a mensagem guardada no Mailgun em vez de evaporar.

**Teste de entrada tem de vir de endereço externo.** Uma mensagem enviada do próprio `MAILER_SENDER_EMAIL` chega ao ingress, responde `204` e é **descartada de propósito** — `MailPresenter#notification_email_from_chatwoot?` compara o remetente com o sender configurado e a mailbox a ignora, senão uma notificação que voltasse viraria conversa, que viraria notificação, em laço. Perdi um teste com isso: o POST aparece no nginx e nenhuma conversa nasce, o que parece defeito e não é.

Provas da entrada, em ordem: entrega direta no MX → conversa 63; **e-mail real de um Gmail → conversa 64**. A segunda é a que vale, porque nenhum envio feito pelo próprio sistema consegue atravessar a guarda acima.

`cortexgen.cloud` não tem SPF na raiz. Não faz falta para o Resend, porque o envelope sai por `send.cortexgen.cloud`, que tem o seu — só faria falta se algum dia sair e-mail direto da raiz.

### 1b. Histórico do bloqueio antigo (mantido para contexto)
`mail.prsbrands.com` (GreenGeeks, 65.60.38.74) é **inalcançável da VPS**: ping 100% loss e timeout em todas as portas (25/80/443/465/587/993). `mtr` mostra a rota morrendo no salto 4 — borda da Hostinger → GreenGeeks. É bloqueio de rede/edge, **não** o firewall CSF do servidor (por isso o suporte "não vê bloqueio"; o whitelist de 24h não teve efeito). Da rede local do Paulo tudo conecta.

O `.env` já está com SMTP correto (`mail.prsbrands.com:465`, `postmaster@prsbrands.com`, senha gravada, `SMTP_TLS=true`) — só não trafega.

**Recomendado:** relay transacional (Brevo 300/dia ou Resend 3k/mês) mantendo remetente `@prsbrands.com`, validando SPF/DKIM por DNS; trocar `SMTP_*` no `.env` + `docker compose up -d --force-recreate rails sidekiq`. IMAP sofre o mesmo bloqueio → inbox de e-mail terá que ser por **encaminhamento** (`MAILER_INBOUND_EMAIL_DOMAIN` + ingress Mailgun/SES).

**Enquanto isso:** reset de senha e convites de agente não saem.

### 2. Expandir o bot para os outros canais ✅ (WhatsApp validado com número real em 2026-08-09)
**Instagram (8) e Messenger (9): funcionando** ✅ — testados com DM real em 2026-08-08, rotas ativas com `nathan-social-dm`. (Diagnóstico útil do primeiro DM sem resposta, execução 9455: webhook e Guard OK, `Persona` voltou `[]` porque a rota estava inativa — o sintoma de rota inativa é o bot ficar mudo com execução `success`.)
**WhatsApp (2): funcionando** ✅ — validado em 2026-08-09 com número real: bot desconectado e reconectado num número novo pela página de sessões, respondendo. Persona `nathan-whatsapp` (`persona_nathan_whatsapp.sql` no scratchpad), canal via OpenWA em `com.cortexgen.cloud` (2 plugins próprios + chatwoot-adapter). Gestão de sessões pelo painel é a pendência 4.

### 3. Agente de voz
Canal de voz nativo é enterprise (fora do escopo MIT). Desenho combinado: a chamada acontece no stack de voz próprio (`voice-agent` / `voicept.cortexgen.cloud` na mesma VPS) e o n8n empurra transcrição + resumo + gravação para uma **inbox API "Voz"** no Chatwoot. `bot_channel_routes.channel_kind` já prevê `voice`.

### 4. Sessões do WhatsApp pelo painel — CONSTRUÍDO em 2026-08-08 (commit `9eabcc9fe`)
Decisões do Paulo: público em duas etapas (interno → clientes finais) e página nativa no fork. Motivação extra: o plugin **`prs-agent` v0.2.2** no OpenWA (sessão `teste`) faz papel parecido com o do Nathan — número novo em sessão nova evita o conflito e usa a integração Chatwoot+n8n.

**O que foi entregue (fase 1, admin-only):**
- Card "WhatsApp Sessions" em Settings → Integrations (aparece só com `OPENWA_API_URL`/`OPENWA_API_KEY` no env) → página que lista sessões com status/telefone/inbox, cria sessão nova, mostra **QR para parear** (polling 3 s até `ready`), start/stop/logout/delete.
- Backend: `lib/integrations/openwa/client.rb` (client HTTParty, header `X-API-Key`), `lib/integrations/openwa/provision_service.rb` (orquestração), controller `api/v1/accounts/{id}/integrations/openwa/sessions` (admin-only via `check_admin_authorization?`; erros do gateway → 422 com mensagem).
- **Provisionamento em 1 clique**: sessão OpenWA → inbox `Channel::Api` com `webhook_url` = ingress do adapter (webhook **escopado à inbox**, assinado com `channel.secret` — melhor que webhook de conta, que manda eventos de todos os canais) → instância do adapter cunhada via REST com `secret = channel.secret` (mata a armadilha do 401) → vínculo `AgentBotInbox` (bot selecionável no dialog) → rota em `bot_channel_routes` via PostgREST (persona de `OPENWA_BOT_PERSONA_SLUG`, default `nathan-whatsapp`) → start da sessão. Rollback best-effort se algum passo falhar.
- Deleção remove sessão + instâncias do adapter; **inbox é preservada** (apagar inbox destrói conversas — fica no fluxo normal de Settings → Inboxes).
- Env no `/opt/cortexgen-chat/.env` (backup em `.env.bak-openwa`): `OPENWA_API_URL=https://com.cortexgen.cloud`, `OPENWA_API_KEY` (= API_MASTER_KEY do container openwa-api), `SUPABASE_REST_URL`, `SUPABASE_SERVICE_ROLE_KEY` (de `/opt/supabase/.env`), `OPENWA_BOT_PERSONA_SLUG=nathan-whatsapp`.

**Melhorias de UX (commit `4faef5c54`, feedback do Paulo no primeiro uso):** a lista mostra o **nome** da inbox (não `#id`); o dialog de criação tem seletor de inbox — padrão "criar inbox nova" (recomendado), mas dá para **reaproveitar uma inbox de API existente** (o webhook dela é reapontado para o ingress da sessão; inboxes já usadas por outra sessão não aparecem); textos deixam explícito que **cada sessão = um número**, que várias sessões rodam em paralelo e que nada precisa ser criado antes. Inbox reaproveitada nunca é destruída no rollback; vínculo de bot e rota Supabase viraram upsert.

**Deploy + dry-run validados em 2026-08-08**: imagem rebuildada, envs ativas, e um provisionamento de teste (`zz-teste-painel`) criou toda a cadeia — sessão com QR real (`qr_ready` + imagem), inbox com webhook no ingress, instância do adapter, Nathan vinculado e rota no Supabase (`bot_route=created`) — e foi limpo em seguida. Falta só o teste com pareamento de número real, que exige o telefone.

**Fase 2 (pendente):** multi-tenant — mapear conta ↔ sessão (hoje a página lista TODAS as sessões do gateway, ok para uso interno), esconder sessões de outras contas, e provisionamento self-service por cliente.

**API do OpenWA (referência):** NestJS em `127.0.0.1:2785` (público via nginx `com.cortexgen.cloud`), auth header `X-API-Key`, spec em `/home/n8n-deploy/apps/openwa/openapi.json`. Sessões: `POST/GET /api/sessions`, `/{id}/qr` (devolve `{qrCode: dataURL, status}`), `/start|stop|logout`, status ∈ created|initializing|qr_ready|authenticating|ready|disconnected|action_required|failed. Instâncias de plugin: `/api/integration/plugins/chatwoot-adapter/instances`.

### 5. Bot Personas no painel — CONSTRUÍDO em 2026-08-08 (commit `0644c3d23`)
Pedido do Paulo (com referência aos cards do GHL): o usuário editar ele mesmo persona, modelos e base de conhecimento do bot, sem SQL.

**Entregue (admin-only, mesmo padrão do OpenWA — Rails proxya o Supabase com a service key; card some sem as envs):**
- Card **"Bot Personas"** em Settings → Integrations + botão "Bot personas" na tela de **Bots** (Settings → Bots).
- Aba **Personas**: cards por persona; editor com prompt (textarea mono), provider/model/fallback, temperature, max_tokens, keywords de handoff (vírgula) e max_turns, ativo/inativo. Slug travado na edição. Criar/excluir persona (excluir falha com mensagem se houver rota apontando — FK).
- Aba **Knowledge base**: docs markdown com global/vinculado por persona (checkboxes), prioridade, ativo. Salvar reescreve os vínculos em `bot_persona_knowledge`.
- Aba **Channels**: tabela inbox → persona com switch liga/desliga (upsert em `bot_channel_routes`); lembra na ajuda que a inbox também precisa do agent bot no Bot Configuration.
- Backend: `lib/integrations/botlayer/client.rb` (PostgREST, valida UUIDs antes de interpolar em filtros) + controllers em `api/v1/accounts/{id}/integrations/botlayer/{personas,knowledge,routes}`.
- **Mudança de prompt/modelo vale na próxima mensagem** — o workflow n8n lê a view a cada chamada, sem deploy.
- Fase 2 junto com o multi-tenant do OpenWA: personas não têm coluna de conta (globais); ok para uso interno.
**Editores em página dedicada (commit `93347405d`)** — o textarea do prompt aparecia com 2 linhas: `rows="14"` não segura altura dentro do flex column limitado do Dialog (o item encolhe). Persona e documento saíram do modal para **páginas full-screen**, montadas **fora do `SettingsWrapper`** (que impõe `max-w-5xl` e altura automática) — rotas de nível superior em `integrations.routes.js`. Layout: editor grande à esquerda (`flex-1` + `min-h-0`, o `min-h-0` é o que impede o encolhimento) e sidebar de configurações à direita. O header da persona mostra **quantos caracteres chegam ao modelo** (prompt + base de conhecimento), que antes era invisível. Combobox virou componente compartilhado `ModelCombobox.vue`.

**AI Providers como integração própria + chaves por conta (commit `335873044`)** — pergunta do Paulo: "onde o cliente a quem eu cedo o painel coloca as chaves dele?". Respostas:
- **Canais de mensageria (Twilio, 360dialog, WhatsApp Cloud, Telegram, Line, Bandwidth, e-mail)**: já é nativo do Chatwoot — Settings → Inboxes → Add Inbox, credenciais por conta e criptografadas (`encrypts :auth_token`). Não duplicar.
- **LLMs**: era a lacuna real. A aba Providers saiu de dentro de Bot Personas e virou o card **AI Providers** em Integrations, com **`bot_providers.chatwoot_account_id`** (unique por conta+slug, SQL em `bot_providers_per_account.sql`) — cada conta só lê/escreve as próprias chaves (filtro aplicado no client PostgREST em toda operação). A view resolve o provider dentro da conta da rota.
- Presets de 1 clique (OpenRouter, Anthropic, OpenAI, Groq, DeepSeek, Mistral) preenchem URL + api_style; só falta colar a chave. Chave nunca volta ao browser (mascarada).
- **Bug de largura corrigido**: as páginas de editor renderizavam com ~890px porque o root era flex item sem `flex-1` dentro do `<main class="flex flex-1">` do Dashboard.vue. Editor de conhecimento perdeu a sidebar (design errado para documento) — metadados em barra compacta no topo, texto em largura total.

- **Uma tela só para ligar o bot num canal — RESOLVIDO**: antes exigia duas chaves em telas diferentes (Bot Configuration na inbox + switch da rota em Channels) — no caso da `numero2`, mensagens chegavam e a rota estava ativa, mas o `AgentBotInbox` não existia e o bot ficou mudo. Agora a aba **Channels** tem coluna **Agent bot** (obrigatória, já pré-selecionada quando a conta tem um único bot) e o `routes_controller` sincroniza as duas pontas: salvar com o switch ligado cria/ativa o `AgentBotInbox`; desligar o switch ou apagar a rota **desfaz o vínculo** — mas só se o bot ligado for o da própria rota, para não mexer em bot atribuído por fora. Bots globais passaram a ser resolvidos por `AgentBot.accessible_to` (o `account.agent_bots.find` do provisionamento OpenWA daria 404 num bot global listado no seletor).
**Catálogo de fornecedores (commit `948fad663`)** — o campo de modelo era texto livre e o provider não fazia nada (o workflow mandava tudo para o OpenRouter; `atendimento-prs` com `anthropic`+`claude-sonnet-5` teria quebrado). Agora:
- Tabela **`bot_providers`** (`slug`, `label`, `base_url`, `api_style` openai|anthropic, `api_key`, `models` jsonb) — SQL em `bot_providers.sql` no scratchpad. `CHECK` de `bot_personas.provider` removido; a view `bot_route_resolved` ganhou `provider_base_url`/`provider_api_style`/`provider_api_key` **no fim** (`CREATE OR REPLACE VIEW` só permite acrescentar colunas no final — reordenar exige DROP).
- Aba **Providers**: cadastrar qualquer endpoint OpenAI-compat ou Anthropic com chave própria; botão **Sync models** lê o `/models` do fornecedor e grava o catálogo (nada de lista fixa envelhecendo). Chave mascarada na leitura; campo vazio na edição mantém a atual.
- Campo de modelo virou `input` + `datalist`: sugere os modelos sincronizados **e** aceita ID digitado. Vale para principal e fallback.
- Card da persona avisa em vermelho quando o provider não existe no catálogo ou não tem chave.
- **Workflow provider-aware**: `MontaPrompt` monta URL/headers/body pelo `api_style` e ramifica no nó **EscolheProvider** — OpenRouter segue pela credencial do n8n (chave nunca entra nos dados de execução), demais fornecedores vão pelo **LLMCustom** com headers montados. Estilo anthropic manda `system` fora do array, **omite `temperature`** e envia `thinking:{type:'disabled'}` (Claude 5 rejeita temperature com 400). `Interpreta` lê os dois formatos de resposta e de usage.
- Validado em produção: conversas 9 e 10 responderam em **4,8 s / 4,4 s** pelo caminho OpenRouter após a mudança; **Sync models** do OpenRouter trouxe **400 modelos** ao vivo.

**Combobox + fallback cross-provider (commit `778d2bb43`, feedback do Paulo):**
- O campo de modelo usava `<datalist>` nativo, que **esconde as opções quando o campo já tem valor** (por isso "a lista não carrega") — trocado por combobox próprio: abre no foco, filtra ao digitar, aceita qualquer ID.
- Fallback ganhou linha própria com **Fallback provider** (Select, "Same as primary" = null) + Fallback model (combobox com o catálogo do provider do fallback). Coluna `bot_personas.fallback_provider` nova; view expõe `fallback_provider_{base_url,api_style,api_key}` (SQL `bot_fallback_provider.sql` no scratchpad).
- Workflow: nós **TentaFallback** (IF) + **LLMFallback** (HTTP) depois do LLM/LLMCustom, que agora têm `onError: continueRegularOutput` (erro vira dado). `MontaPrompt` monta `fallbackSpec` (URL/headers/body do provider do fallback); `Interpreta` detecta o formato da resposta pelo shape (openai|anthropic), não pelo contexto.
- **Regra da chave**: fallback em outro provider (ou retry separado no mesmo) só acontece se a chave do provider do fallback estiver gravada no `bot_providers` — sem chave, só o fallback nativo do array do OpenRouter (que NÃO cobre erro de validação, ex. modelo inexistente: o request morre antes do roteamento).
- **Provado E2E** com provider mock (workflow `ZZ Mock LLM`, arquivado): primário com modelo inválido → LLMFallback chamou o mock → resposta postada na conversa 13, log `mock-fallback-1`. Regressão do caminho normal OK (conversas 11 e 14, ~2,6 s).

- **Deploy validado em 2026-08-08**: client lê personas (4), docs (`prs-brands-core`) e rotas (inboxes 2/8/9/10/12 ativas) em produção. Obs.: as experiências do Paulo com o pareamento criaram inboxes extras ("WhatsApp — Numero2" #14, "WhatsApp — Prs" duplicadas ~#12/#13) e uma rota ativa na inbox 12 — dá para revisar/limpar pela própria aba Channels + Settings → Inboxes.

### 6. Super Admin — conciliação com o painel de conta (2026-08-09)

Auditoria do que fizemos no Agent Dashboard vs. o que o Super Admin enxerga. **Branding já estava ok** (nav diz "CortexGen Chat", cards premium podados do `app/helpers/super_admin/features.yml` no commit de white label). **Agent bots** também: com o `AgentBot.accessible_to` de hoje, bot global criado no Super Admin funciona no painel de conta.

**Entregue:**
- **Feature flags por conta**: `whatsapp_sessions`, `bot_personas`, `ai_providers` em `config/features.yml` (`column: feature_flags_ext_1`, `enabled: false`). Aparecem em Super Admin → Accounts → Edit. Checadas em `Integrations::App#active?/enabled?` (esconde o card) **e** nos controllers (`raise Pundit::NotAuthorizedError`, que é o gate de verdade). `bot_personas` e `ai_providers` são separadas de propósito: ceder o painel de bots não obriga a ceder as chaves de LLM.
- **Config global saiu do ENV**: `OPENWA_API_URL/KEY/BOT_PERSONA_SLUG` e `SUPABASE_REST_URL/SERVICE_ROLE_KEY` passaram a ser lidas por `GlobalConfigService.load`, com entradas em `config/installation_config.yml` e páginas **Super Admin → Settings → WhatsApp Gateway / Bot Layer**. O `GlobalConfigService` cai no ENV enquanto o `InstallationConfig` não existir e **grava o valor do ENV na primeira leitura** — não precisa migrar nada, e as envs do `.env` podem sair depois.
- **Prontidão das outras integrações** (nenhuma ligada, decisão do Paulo): `shopify_integration` perdeu `chatwoot_internal` (a flag era invisível no Super Admin self-hosted, então o card nunca ligava) e a página **AI Assistant** (`config_key: captain`) voltou ao Super Admin. Agora toda integração listada no painel é conectável só colando credencial — exceto o card **OpenAI**, ver abaixo.

**Card OpenAI NÃO é morto** (corrigido em 10/08). Ele de fato não tem processor no `HookJob` — mas não precisa: é **cofre de chave por conta** para o assistente de escrita, e o próprio `hook.rb` diz `# OpenAI integration migrated to Captain::EditorService`. Serve para o cliente a quem se cede o painel pagar a própria OpenAI em vez da chave da instância. **Manter.**

### As quatro integrações da tela, auditadas (10/08)

Nenhuma é enterprise — todas têm o código na árvore MIT e os gems no Gemfile. Nenhuma estava configurada (`Integrations::Hook.count == 0`), que é por que a tela mostrava tudo "Disabled".

| card | funciona na MIT? | o que exige |
|---|---|---|
| **OpenAI** | sim, como cofre de chave | chave OpenAI da conta (o endpoint é global — ver pendência 7) |
| **Dialogflow** | sim — `google-cloud-dialogflow-v2` no Gemfile, processor em `lib/` | projeto GCP + JSON de service account, **por inbox** |
| **Google Translate** | sim — `google-cloud-translate-v3` no Gemfile | projeto GCP + JSON |
| **Cloudflare RealtimeKit** (card `dyte`) | sim, e **já migrado** | `account_id` + `app_id` + `api_token` |

**O assistente de escrita foi testado e funciona** — fecha a lacuna 4 de "Lacunas conhecidas". `Captain::RewriteService` com a chave de instância reescreveu *"oi tudo bem quero saber precos"* em *"Olá, tudo bem? Gostaria de obter informações sobre os preços..."*.

**O card `dyte` não fala mais com a Dyte.** `lib/dyte.rb` aponta para `https://api.cloudflare.com/client/v4/accounts/{id}/realtime/kit/{app}/…` — a Cloudflare comprou a Dyte e esta versão acompanhou. O produto está em **Beta, grátis** (10 mil min, depois US$0,002/min). Dá um **botão de chamada de vídeo na conversa** (`VideoCallButton.vue`); o cliente entra pelo widget.

**Dialogflow é um segundo motor de bot.** Funciona, mas ligado numa inbox que já tem persona do bot layer resulta em dois cérebros respondendo à mesma mensagem. Decisão do Paulo em 10/08: **deixar visível**.

### RealtimeKit — EM STAND BY (10/08), erro do lado da Cloudflare

Tentativa de configurar parou na **validação de credencial do próprio Chatwoot**, que roda antes de salvar e por isso **não deixou estado pela metade** (`Integrations::Hook.count` segue 0).

`Integrations::Cloudflare::RealtimeKitCredentialsValidator` faz duas chamadas, nesta ordem:

```
1. GET /user/tokens/verify              exige 200 + success:true + result.status == "active"
2. GET /accounts/{id}/realtime/kit/apps confere se o app_id está na lista
```

Parou na **1**: `invalid_api_token`. Causa provável — *Global API Key* no lugar de *API Token*, que são credenciais diferentes na Cloudflare e só a segunda passa nesse endpoint. O token certo se cria em My Profile → API Tokens → Custom Token, escopo **Account → Realtime → Edit**, com a conta em Account Resources.

**Para retomar:** `ops/set-realtimekit.sh` (instalado em `/opt/cortexgen-chat/`). Ele pede os três valores sem ecoar o token, roda as **mesmas duas chamadas com a resposta crua da Cloudflare na tela** — inclusive listando os `app_id` que existem na conta, útil quando o app está certo e o id foi copiado errado — grava o hook e cria uma reunião de teste.

**Armadilha para depois de conectar:** ao adicionar participantes o Chatwoot pede o preset **`group-call-host`** (com `group_call_host` como reserva). Sem um preset com um desses nomes no app, a reunião é criada mas ninguém entra — e nada avisa até alguém clicar no botão de chamada.

**Achado que corrige uma premissa**: os serviços de escrita do composer (`rewrite`, `summarize`, `reply_suggestion`, `label_suggestion`) estão em `lib/captain/` e `lib/llm/` — **árvore MIT**, não enterprise. `Llm::Config` lê `CAPTAIN_OPEN_AI_API_KEY` + `CAPTAIN_OPEN_AI_ENDPOINT` do `InstallationConfig` e o `openai_api_base` é configurável, ou seja **aponta para o OpenRouter que já usamos**. O que está em `enterprise/` é o Captain "produto" (assistentes, documentos, RAG). Falta validar ponta a ponta; a flag `captain_integration` está marcada `premium`.

~~**Ainda aberto (fase 2 multi-tenant):** `bot_personas` e `bot_knowledge_docs` não têm coluna de conta~~ — **fechado** em `8d8b268f2`, ver abaixo.

### Isolamento entre contas na camada de bots (10/08, `8d8b268f2`)

`bot_channel_routes` e `bot_providers` já eram por conta; **persona e documento ficaram de fora — e são justamente o que o cliente escreve**. Com o painel cedido a uma segunda conta, o admin dela abriria a lista e editaria o `system_prompt` da primeira. Preventivo: hoje só existe a conta 1, mas no dia da segunda já nasceria vazando.

SQL em `db/botlayer/bot_layer_per_account.sql`, aplicado (4 personas e 2 docs migrados para a conta 1):

- `chatwoot_account_id` **NOT NULL** nas duas tabelas, sem default — linha sem conta é bug de chamador e deve falhar alto, não virar persona órfã.
- **Slug único dentro da conta.** Era único no servidor: o segundo cliente que criasse `atendimento` receberia erro de duplicado por causa de uma linha que ele não pode ver.
- Filtro por conta em **toda** leitura e escrita do client PostgREST, inclusive nas de id conhecido — senão saber o UUID bastaria para editar.
- **`is_global` passa a significar global dentro da conta.** Esta é a parte que não se vê: documento global entra no prompt de todas as personas, e sem o recorte o texto de um cliente sairia pela boca do bot de outro. As duas views (`bot_route_resolved` e `bot_persona_resolved`) ganharam `d.chatwoot_account_id = p.chatwoot_account_id` no join.

Dois caminhos que passariam batido, porque não estão na tela de personas:

- **Provisionamento do WhatsApp** buscava persona por slug sem conta (`fetch_persona_id`), e o slug padrão vem de config **global** — apontaria para a persona homônima de quem tivesse criado primeiro.
- **Rota de canal** aceitava `persona_id` vindo do navegador sem conferir de quem era: bastava apontar a própria inbox para o UUID alheio para o bot responder com o prompt de outro cliente.

**Provado com uma conta 999 de teste, nas duas direções** (fixtures removidas depois):

```
conta 1 recebe o próprio doc global · não recebe o da 999   → t / f
conta 999 recebe o próprio          · não recebe o da 1     → t / f
personas visíveis pela conta 1                              → só as 4 dela
conta 1 resolve a persona da 999 por slug                   → nil
conta 1 edita a persona da 999 com o UUID na mão            → nil, nome intacto
```

Depois do deploy: 7 rotas resolvendo com prompt e chave em `bot_route_resolved`, e a config de voz montando com 24.671 caracteres.

**O que ainda falta para o segundo inquilino:** e-mail (pendência 1, bloqueia convite de agente e reset de senha) e a assinatura do webhook do bot no n8n.

### 7. CortexGen AI — assistente de escrita (2026-08-09, commit `0759ce331`)

O "Captain" do Chatwoot são **duas coisas** com o mesmo nome:

| | Captain **produto** | Captain **tasks** |
|---|---|---|
| O que é | Assistentes, documentos, RAG, copilot lateral | Assistente de escrita do compositor: reescrever, resumir, sugerir resposta, sugerir etiquetas |
| Código | `enterprise/` | `lib/captain/` + `lib/llm/` — **MIT** |
| Flag | `captain_integration` (premium, off) | `captain_tasks` — `enabled: true`, **já ligada em toda conta** |

Só o segundo é nosso. Renomeado para **CortexGen AI** em todas as strings EN visíveis; rotas, flags e classes seguem `captain*` de propósito, para não divergir do upstream.

**De quem é a chave** — `lib/captain/base_task_service.rb:179`, precedência:
1. **Chave da conta**: card **OpenAI** em Settings → Integrations do cliente (`account.hooks` do app `openai`). Todos os 7 serviços de tarefa marcam `use_account_openai_hook? = true`.
2. **Fallback, chave nossa**: `CAPTAIN_OPEN_AI_API_KEY` em Super Admin → Settings → CortexGen AI.

O toggle "Show label suggestions" dentro do card OpenAI é o que liga as sugestões de etiqueta. **O card OpenAI não é decorativo** — ele não processa eventos (não está no `HookJob`), é cofre de chave. Não remover.

**Pegadinha do endpoint**: `api_base` lê só `CAPTAIN_OPEN_AI_ENDPOINT`, que é **global**. Todas as chaves — a nossa e a dos clientes — têm que ser do mesmo fornecedor. Decisão de 2026-08-09: **começar com OpenAI direto** (endpoint vazio = `https://api.openai.com/`).

**Para trocar por OpenRouter depois** não basta trocar o endpoint: `config/llm.yml` é um catálogo fechado por feature (default `gpt-4.1-mini`) e o `Llm::FeatureRouter` só aceita modelo dessa lista, validada contra `config/llm_models.json`. Os IDs teriam que virar `openai/gpt-4.1-mini` etc. — reescrita do catálogo, ~meio dia.

`CAPTAIN_OPEN_AI_MODEL` **não afeta o assistente de escrita** (só o runtime de agents em `config/initializers/ai_agents.rb`); os modelos vêm do `config/llm.yml` por feature.

### 8. Cosméticas
- ~~**Logos** são placeholders gerados~~ — **arte oficial no ar** em 10/08 (`2e1389f00`). 37 arquivos gerados por `ops/brand/gerar.sh` a partir de `app/assets/images/ico.png` (512×512, ícone quadrado) e `cga.png` (350×100, logo horizontal). Rodar de novo quando a arte mudar; é idempotente.

  Três coisas que a geração teve de resolver, e que voltam se alguém regerar à mão:
  - **O texto do logo é branco**, então só serve em fundo escuro — e o painel usa os dois (`block dark:hidden` / `hidden dark:block`). O `logo.svg` recebe o texto recolorido para `#1B1B1B`, o mesmo escuro do ícone.
  - **Os destinos são SVG e a arte é PNG.** Não dá para vetorizar, então o SVG embute o PNG em base64: mantém os nomes que o código e o `installation_config.yml` já apontam, e os logos aparecem a 32–40 px de altura, bem abaixo da resolução da arte.
  - **O ícone do balão do widget** fica sobre a cor que o cliente escolhe, então é monocromático: só o símbolo recortado (o texto começa na coluna 108), em branco.

  Os `favicon-badge-*` também foram refeitos, com o ponto vermelho nas proporções medidas no arquivo antigo (`#EF4444`, centro em 0,797 do lado, raio 1/6) — senão o favicon voltaria a ser roxo justamente quando chega mensagem.

  `ops/brand/png_tool.py` existe porque a máquina não tem PIL nem ImageMagick: lê e escreve PNG com a biblioteca padrão e cobre recolorir, recortar e o ponto de não lido. O `sips` do macOS faz o resto.

- ~~**As cores do tema ainda são as do Chatwoot**~~ — **trocadas** em 10/08 (`f7a269ae6`).

  **O token `n-brand` em `theme/colors.js` manda em 128 lugares**, incluindo o botão de login. É a única mudança que realmente importa; o resto é consequência.

  **O verde do tema NÃO é o verde do logo, de propósito.** `#63BE80` aparece 49 vezes como fundo de botão com `text-white` **fixo no componente**, e branco sobre ele dá **2,28:1** — menos da metade do mínimo de 4,5:1, e pior que o azul que estava lá (3,78:1). O tema usa **`#388550`**, que mantém o matiz (h=0,386) e chega a **4,53:1** com branco. Num botão esse contraste independe do tema claro/escuro, porque é texto contra o próprio fundo do botão — foi isso que permitiu um valor chapado em vez de variável por tema.

  Se algum dia alguém "corrigir" o token para o verde do logo achando que é inconsistência, o resultado é texto ilegível em todo botão primário.

  **Três lugares casavam fundo da marca com texto azul** (botão suave, aba ativa, etiqueta de sugestão) e passaram a usar a própria marca: 4,01:1 contra os 4,22:1 anteriores — paridade, sem o choque verde/azul.

  Fora do painel: cor padrão do formulário de inbox, `DEFAULT_WIDGET_COLOR` do onboarding, `DEFAULT_COLOR` do portal, e o fundo do balão no `sdk.js` (o que aparece no site do cliente antes de a config carregar).

  **Fica de fora** o default da coluna `widget_color` no banco (`#1f93ff`), que exigiria migration para um caso que a UI já cobre mandando a cor. E a paleta legada `woot.*`, derivada do azul do Radix, que sobrevive em telas marginais (billing enterprise, playground do Super Admin).

  **Atenção ao dado:** o `widget_color` das inboxes existentes foi atualizado para `#388550`. A inbox 10 estava em `#0E0E0E` — se aquilo era escolha deliberada, é um campo em Settings → Inboxes.
- ~~**Locales não-EN** ainda dizem "Chatwoot"~~ — **resolvido** em 10/08 (`fe1ff5bac`), **sem editar arquivo de locale**.

  Eram 2.565 ocorrências em **57 idiomas** (46 só no pt_BR). Editar os arquivos seria errado duas vezes: o `AGENTS.md` manda mexer só em `en.json` porque os demais vêm do Crowdin, e qualquer edição ali volta atrás no próximo merge com o upstream.

  A troca vai como **`postTranslation` do vue-i18n** (opção de `ComposerOptions`, roda depois do `t()`), em `shared/helpers/installationBranding.js`, ligada no `dashboard.js` e no `v3app.js` — os dois entrypoints que carregam o layout com `window.globalConfig`. Um lugar cobre todos os idiomas e sobrevive ao merge.

  **O regex não é troca cega.** `(?<![\w/@.])chatwoot(?!\.[a-z])` preserva domínio (`app.chatwoot.com`, `chatwoot.help`), caminho de repositório (`github.com/chatwoot/...`) e **nome de variável de interpolação** (`{latestChatwootVersion}`), onde trocar quebraria a mensagem. Medido contra os próprios arquivos de locale: **2.062 trocas e 503 preservados**, todos eles URL, chave ou variável. Sem `INSTALLATION_NAME`, ou com o nome de fábrica, não mexe em nada.

  Widget e portal não precisaram: o `shared/components/Branding.vue` já lê `BRAND_NAME` do config e aplica `replaceInstallationName`, e a conta tem `disable_branding` ativo.

  **Verificado até onde dá sem sessão:** o regex está no bundle servido em produção (`new RegExp("(?<![\\w/@.])chatwoot(?!\\.[a-z])","gi")`). A tela de login está fixada em `en` (`locale: 'en'` no `v3app.js`), então **a confirmação visual em pt_BR exige estar logado** com o idioma trocado no perfil.
- **Push mobile**: relay da Chatwoot desativado (`ENABLE_PUSH_RELAY_SERVER=false`); gerar VAPID se quiser web push.
- ~~**Segurança do webhook**~~ — **fechado** em 10/08, ver "O webhook do bot passou a exigir assinatura" abaixo. Não eram ~10 linhas.

---

## Operação

```bash
# Deploy — SEMPRE construir com :test antes (ver "Protocolo de deploy" no topo)
cd /opt/cortexgen-chat/src && git pull \
  && docker build -f docker/Dockerfile -t cortexgen-chat:test . \
  && docker build -f docker/Dockerfile -t cortexgen-chat:v1 . \
  && cd .. && docker compose up -d --force-recreate rails sidekiq \
  && docker compose ps
```

```bash
# Serviço de voz — o smoke test NÃO é opcional (ver armadilha do Pipecat no topo)
cd /opt/cortexgen-voice && docker compose build \
  && docker compose run --rm --entrypoint python voice smoke.py \
  && docker compose up -d && curl -s localhost:8095/health
```

- Logs do bot de voz: `docker logs -f cortexgen-voice`
- Logs: `docker compose logs -f rails` em `/opt/cortexgen-chat`
- **Mudança no `.env` exige `up -d --force-recreate`** — `restart` não relê o env
- Rails console: `docker compose exec rails bundle exec rails console`
- Supabase: `docker exec supabase-db psql -U postgres -d postgres`
- Acesso SSH: `ssh -i ~/.ssh/id_ed25519_cortexgen root@187.77.20.155`
- n8n: compose em `/docker/n8n-y4jd/`, container `n8n-y4jd-n8n-1`

### Scripts de configuração (`ops/`)

Todos perguntam a credencial sem exibi-la e fazem backup antes. **A chave nunca deve passar por chat nem por histórico de shell** — é por isso que existem.

| script | o quê |
|---|---|
| `ops/set-resend.sh` | SMTP de saída pelo Resend |
| `ops/set-mailgun-inbound.sh` | entrada de e-mail pelo ingress do ActionMailbox |
| `ops/set-realtimekit.sh` | Cloudflare RealtimeKit — diagnostica antes de gravar |
| `ops/brand/gerar.sh` | os 37 arquivos de marca, a partir de `app/assets/images/{ico,cga}.png` |
| `ops/n8n/guard.js` | o nó Guard do workflow, com a verificação de assinatura |

SQL da camada de bots em `db/botlayer/`, aplicado com
`docker exec -i supabase-db psql -U postgres -d postgres < arquivo.sql`.

### Como transferir um segredo sem vê-lo

Padrão usado três vezes nesta sessão, vale repetir: leia do banco de origem para um arquivo, `docker cp` para o destino, leia e apague lá dentro. O valor nunca é impresso nem passa por linha de comando. Exemplo do que foi feito com o segredo do agent bot para o n8n em "O webhook do bot passou a exigir assinatura".

## Decisão de licença (não reabrir sem motivo)

Rodamos a **edição Community (MIT)** com `DISABLE_ENTERPRISE=1`. Isso é o que torna o white label legal e desliga o job noturno que reverteria o branding. SLA, Captain AI, custom roles, audit logs, SAML e canal de voz ficam de fora — são da licença comercial da Chatwoot. Para tê-los, é comprar a assinatura e remover o env var.
