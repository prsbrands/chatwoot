# Recursos nativos do Chatwoot — o que serve na nossa edição MIT

Levantamento de 2026-08-19, contra a produção em `prs.cortexgen.cloud` (`DISABLE_ENTERPRISE=1`).

**Como cada veredito foi obtido, porque isso muda a conclusão:** não basta ver a tela nem a
flag. O que decide é **onde mora a implementação** — recurso cuja lógica vive em `enterprise/`
não carrega aqui, mesmo com o checkbox marcado e a tela renderizando. Cada linha abaixo foi
conferida no código e no estado real da instalação, não na documentação da Chatwoot.

| recurso | onde | veredito |
|---|---|---|
| Push notifications (Firebase) | Super Admin → Settings → General | serve, mas **exige app móvel próprio** |
| Inbound email domain | Super Admin → Settings → Email | **já em uso**, e por conta é o caminho do white label |
| Limites de e-mail por conta | Super Admin → Settings → Email | **morto** — só vale no Chatwoot Cloud |
| Automation | conta → Settings → Automation | **funciona**, nunca usado |
| Auto Resolve | conta → Settings → Conversation Workflow | **funciona**, nunca configurado |
| Required Attributes | conta → Settings → Conversation Workflow | **morto** — enterprise |
| Macros | conta → Settings → Macros | **funciona**, nunca usado |
| Canned Responses | conta → Settings → Canned Responses | **funciona**, nunca usado |

---

## A síntese que vale mais que as peças: há três portas para o n8n

Descoberta ao analisar automação e macro. Hoje só a primeira é usada, e as outras duas
resolvem casos que ela não alcança.

| porta | dispara por | assinada? | serve para |
|---|---|---|---|
| **AgentBot** (`/webhook/cortexgen-bot`) | mensagem recebida, com bot ligado na inbox | **sim**, HMAC com `AgentBot#secret` | o bot conversando |
| **Automação** (`send_webhook_event`) | qualquer evento de conversa, por condição | **não** | gatilhos que o bot não cobre: conversa resolvida, parada há X, prioridade mudou |
| **Macro** (`send_webhook_event`) | o agente apertar o botão | **não** | ação humana deliberada, e em lote |

**As duas últimas não podem apontar para `/webhook/cortexgen-bot`.** O `WebhookJob` é chamado
sem secret (`Webhooks::Trigger` só assina quando `@secret.present?`), então o Guard recusaria —
corretamente. Workflow que receba automação ou macro precisa de porta própria com autenticação
própria: token em header ou segredo no path.

---

## Push notifications — Firebase (Super Admin → Settings → General)

**Para que serve:** push nos **apps móveis**. Não toca o navegador — esse caminho é outro e
independente (WebPush + VAPID).

`Notification::PushNotificationService#send_fcm_push` só dispara para assinaturas
`subscription.fcm?`, identificadas por `device_id` + `push_token`, que só um app móvel cria.
Navegador cria assinatura `browser_push`, com `endpoint`/`p256dh`/`auth`.

**A pegadinha que decide se vale a pena:** token de FCM é emitido por projeto Firebase + build
do app. A credencial só empurra para tokens do **próprio** projeto — ou seja, só para um app que
nós mesmos publiquemos. O app oficial da Chatwoot está registrado no Firebase deles.

É por isso que existe o relay, e o código trata os dois como mutuamente exclusivos:

```ruby
def send_fcm_push(subscription)        return unless firebase_credentials_present?
def send_push_via_chatwoot_hub(...)    return if     firebase_credentials_present?
```

**O relay tem um custo que não é dinheiro:** `ChatwootHub.send_push` posta o `fcm_options`
inteiro em `hub.chatwoot.com/send_push`, e o `body` é `push_message_body` — **o texto da
mensagem do cliente**. Conteúdo de conversa de terceiro saindo para servidor da Chatwoot, o que
briga com a premissa do white label.

**Plano gratuito serve.** FCM é grátis e sem teto no Spark; o escopo pedido é só
`https://www.googleapis.com/auth/firebase.messaging`, com uma service account. Não precisa Blaze.

**Estado em 19/08:** `FIREBASE_PROJECT_ID` nil, credenciais vazias, `ENABLE_PUSH_RELAY_SERVER=false`
— **nenhum push móvel sai por nenhum dos dois caminhos**, e há zero `NotificationSubscription`.

**Correção a uma nota antiga do handoff:** web push **já está disponível**, não há VAPID a gerar.
O `VapidService` cria e persiste o par na primeira leitura, e o `InstallationConfig VAPID_KEYS`
existe desde 07/08 (conferido pelo `created_at`, justamente porque a sonda poderia tê-lo criado).
Falta só um agente aceitar a permissão no navegador.

**Ordem recomendada:** web push primeiro (custo zero, já pronto) → Firebase próprio quando
existir app CortexGen → relay só se aceitar marca e tráfego de terceiro. Antes de contar com o
app próprio, **conferir a licença do app móvel da Chatwoot**, que é repositório separado.

---

## Inbound email domain (Super Admin → Settings → Email)

A tela tem três campos e **só um faz algo aqui**.

| campo | o que faz | vale? |
|---|---|---|
| `MAILER_INBOUND_EMAIL_DOMAIN` | domínio do endereço de resposta `reply+<uuid>@` | **sim, em uso** |
| `ACCOUNT_EMAILS_LIMIT` | teto diário de e-mails por conta | **morto**: `within_email_rate_limit?` abre com `return true unless ChatwootApp.chatwoot_cloud?` |
| `ACCOUNT_EMAILS_PLAN_LIMITS` | limites por plano | **morto duas vezes**: só lido em `enterprise/` |

**O que o campo faz:** monta o Reply-To de continuidade — `reply+<conversation.uuid>@<domínio>`.
Quando o contato responde, o `ApplicationMailbox` casa o UUID e devolve a mensagem **à mesma
conversa** em vez de abrir outra. Não confundir com o domínio da inbox de e-mail.

Precedência: `account.domain` → Super Admin → ENV.

**A tela mente, e o motivo é sutil.** O campo aparece **vazio** e o sistema funciona pelo ENV
(`cortexgen.cloud`): `Account#inbound_email_domain` usa `GlobalConfig.get`, que **não cai no
ENV** — diferente do `GlobalConfigService.load` usado no Bot Layer, que grava o ENV no
`InstallationConfig` na primeira leitura. Quem abrir a tela conclui que não está configurado.

**O que interessa ao white label:** hoje as **duas contas** respondem como `cortexgen.cloud` —
o cliente da dagente vê `reply+<uuid>@cortexgen.cloud`. O conserto não precisa de código: o campo
`account.domain` tem precedência e existe exatamente para isso (o comentário no modelo é
explícito: *"Do not repurpose it for a website"*). E a **conta 2 já está com os flags
`custom_reply_domain` e `custom_reply_email` ligados**, com os campos em branco — a tela já está
no painel dela, esperando.

Falta, para usar: cada domínio de inquilino precisa da própria cadeia `MX → Mailgun → route →
ingress`. A route atual é `.*@cortexgen.cloud`, que é por que o `reply+` já é capturado.

**Lacuna de teste:** o caminho `reply+` está montado e **nunca foi exercitado** — o handoff
registra conversas nascendo de e-mail, nenhuma resposta caindo dentro de conversa existente.

---

## Automation (conta → Settings → Automation)

**Funciona, nunca foi usada:** `AutomationRuleListener` está registrado no dispatcher assíncrono
em produção; **0 regras** nas duas contas.

**É MIT.** O overlay em `enterprise/` acrescenta só a condição `sla_policy_id` e a ação `add_sla`;
em produção a lista tem 19 ações, sem `add_sla`.

| | |
|---|---|
| Gatilhos (5) | `conversation_created`, `conversation_updated`, `conversation_opened`, `conversation_resolved`, `message_created` |
| Condições (18) | content, email, country_code, status, message_type, assignee_id, team_id, referer, city, company_name, **inbox_id**, mail_subject, phone_number, priority, **conversation_language**, labels, private_note, browser_language |
| Ações (19) | send_message, add/remove_label, assign_agent/team, change_status, resolve/open/pending/snooze, change_priority, mute, add_private_note, send_attachment, send_email_to_team, send_email_transcript, **send_webhook_event** |
| Atraso | `execution_delay`, 10 min a 30 dias (disparado pelo cron de 5 min) |

**Usos que valem aqui:**

1. **Fila do bot vigiada** — conversa em `pending` (onde as do bot ficam) há 30 min →
   `open_conversation` + `assign_team`. É a rede de segurança para o bot mudo, que é o modo de
   falha recorrente do projeto e hoje só se descobre olhando.
2. **Etiqueta por canal e idioma** — `inbox_id` / `conversation_language` → `add_label`. No
   multi-tenant é o que faz relatório por canal deixar de ser garimpo.
3. **Handoff editável pelo cliente** — `message_created` + `content contains` →
   `open_conversation`. Duplica o que hoje está no nó `Interpreta`; só vale se o cliente precisar
   mexer sozinho.

**Duas armadilhas:**

- **O listener não ignora o bot.** Ele pula evento gerado por automação, atividade e auto-reply,
  mas **não** pula mensagem escrita pelo bot. Regra em `message_created` sem filtro dispara também
  nas respostas do Nathan e do Vitor. **Filtre por `message_type = incoming`, sempre.**
- **Auto-resolver já existe fora daqui** (`auto_resolve_after`, abaixo). Montar o mesmo
  comportamento como automação cria dois donos. Escolha um.

---

## Conversation Workflow (conta → Settings)

Duas caixas com destinos opostos.

### Auto Resolve — MIT, funciona, não configurado

Flag `auto_resolve_conversations` **true nas duas contas** e a cadeia existe:

```
trigger_scheduled_items_job | */5 * * * * | TriggerScheduledItemsJob
   └─ Account::ConversationsResolutionSchedulerJob → Conversations::ResolutionJob
```

Mas `auto_resolve_after` é **nil**, e o agendador filtra por `Account.with_auto_resolve` — sem o
valor, nenhuma conta entra na varredura. Campos: minutos, mensagem antes de resolver, ignorar
quem aguarda cliente, e **etiqueta ao resolver** (`auto_resolve_label`).

**O detalhe que decide se serve:** os dois escopos partem de `open`.

```ruby
scope :resolvable_all, ->(min) { open.where('last_activity_at < ?', ...) }
```

As conversas do bot ficam em **`pending`** — o auto-resolver **não as toca**. Bom, porque não
fecha conversa que o bot ainda conduz; ruim, porque a fila `pending` abandonada continua sem
rede. Para essa, o caminho é automação, não este campo.

Se for usar: 3 a 7 dias, com **etiqueta** em vez de mensagem — mensagem automática de
encerramento em WhatsApp e widget costuma reabrir a conversa em vez de fechar.

### Required Attributes — enterprise, morto

Obriga o agente a preencher atributos antes de resolver. Prova direta em produção:

```
Account responde a conversation_required_attributes?   false   ← não há onde gravar
```

`store_accessor` em `Enterprise::Concerns::Account`, checagem em
`Enterprise::Macros::ExecutionService`, param permitido em `Enterprise::Api::V1::AccountsSettings`
— nada carrega com `DISABLE_ENTERPRISE=1`.

**A armadilha era pior que a ausência:** a flag é `premium`, mas premium **não é escondida** no
Super Admin (o helper faz `regular.merge(premium)`, só ordena depois). Marcar fazia o bloco
renderizar, o agente configurar, o save responder **sucesso** e o strong params descartar em
silêncio. Escondida em 19/08 — ver a seção de flags abaixo.

---

## Macros (conta → Settings → Macros)

**Funciona e é MIT completo**, com **0 macros criadas**. O overlay em `enterprise/` acrescenta
uma coisa só: a guarda de atributos obrigatórios antes de resolver — inerte aqui, já que a
feature que ela protege não existe nesta edição.

Macro é ação **disparada pelo agente**, não por evento, e aceita `conversation_ids` no plural —
funciona **em lote**, da lista de conversas.

**16 ações**, todas subconjunto das 19 da automação:

```
só na automação: send_email_to_team, open_conversation, pending_conversation
só na macro:     (nenhuma)
```

**Visibilidade:** `set_visibility` força `personal` quando quem cria é agente — agente não cria
macro global nem por API. Editar ou apagar global exige administrador.

**Duas coisas para saber antes de usar:**

1. **O editor esconde uma ação que o backend aceita.** `ACTIONS_ATTRS` tem 16; o `constants.js`
   do editor oferece **15**. A que falta é `change_status` — a única forma de mandar uma conversa
   de volta para **`pending`**, que é onde as do bot vivem. Macro "devolver ao Nathan" é possível
   por API e **não é construível pela tela**.
2. **Macro que falha é invisível, em três camadas.** O controller responde `head :ok` antes de
   executar, o job roda async, e o serviço faz `rescue StandardError` **por ação**, seguindo para
   a próxima. O agente vê sucesso sempre. E o `capture_exception` só grita com `SENTRY_DSN`, que
   **não existe** neste `.env` — sobra `Rails.logger.error`. Macro de cinco ações cuja terceira
   falha executa as outras quatro, não avisa ninguém, e só aparece com grep no log.

**Usos:** o `send_webhook_event` (`event: 'macro.executed'`) é a porta do agente para o n8n.
O **Call demo** que construímos como componente Vue faz conceitualmente isso — uma macro chegaria
perto **sem deploy** (perdendo o preenchimento do telefone e a escolha de persona). Para a
*próxima* ação desse tipo, macro é o caminho barato. Primeiras duas que valem: **"Escalar para
humano"** (assign_team + change_priority + nota privada) e **"Pedir orçamento"** (webhook).

---

## Canned Responses (conta → Settings → Canned Responses)

**Funciona, é MIT puro e não tem overlay enterprise nenhum.** Flag ligada nas duas contas,
**0 respostas cadastradas**.

É a peça mais simples do painel: `short_code` + `content`, único por conta. O agente chama pelo
atalho `/` no compositor, e o texto entra na caixa **para ser editado antes de enviar** — não
envia sozinho, ao contrário da macro.

**Aceita variáveis**, e é isso que a torna mais útil do que parece. O
`replaceVariablesInMessage` do editor resolve na hora da inserção:

```
conversation.id
contact.id · contact.name · contact.first_name · contact.last_name · contact.email · contact.phone
agent.name · agent.first_name · agent.last_name
```

**Três diferenças de governança em relação a macro, e uma delas é um risco:**

| | Canned Response | Macro |
|---|---|---|
| escopo | **da conta inteira**, sem visibilidade pessoal | pessoal ou global |
| quem cria/edita/apaga | **qualquer agente** — o controller não tem `check_admin_authorization?` nem policy dedicada | agente só cria pessoal; global só admin |
| o que faz | insere texto no compositor, humano revisa | executa ações, sem revisão |

O risco é o do meio: **qualquer agente pode apagar ou reescrever a resposta padrão de todo mundo**,
e não há registro de quem fez (o modelo não tem `created_by`, diferente de `Macro`). Numa conta
com vários agentes isso aparece cedo. Não há conserto por configuração — seria código.

**Usos que valem aqui:**

1. **Padronizar o que o bot não cobre.** O Nathan e o Vitor respondem com prompt; o humano que
   assume depois do handoff hoje escreve do zero. Meia dúzia de respostas com `{{contact.first_name}}`
   fecha essa lacuna sem tocar em persona nem em workflow.
2. **Multi-tenant sem trabalho extra:** já é por conta, então cada cliente monta as suas e não
   enxerga as dos outros. Ao contrário de persona e base de conhecimento, aqui o isolamento veio
   de fábrica.
3. **Complemento da macro, não concorrente:** canned response quando o humano precisa revisar
   antes de mandar; macro quando a ação é mecânica e em lote.

---

## Flags premium escondidas do Super Admin (19/08)

Auditoria motivada pelo `conversation_required_attributes`: das 14 flags `premium` visíveis em
Accounts → Edit, **13 eram checkbox que liga e não faz nada**, porque a implementação vive em
`enterprise/`. Todas ganharam `chatwoot_internal: true` em `config/features.yml`, que é o
mecanismo do próprio arquivo (*"should not be shown in the UI for other self hosted
installations"*) — só acrescenta uma chave, sem mexer na ordem das entradas, de que dependem as
posições de bit persistidas.

**Escondidas (12):** `conversation_required_attributes`, `audit_logs`, `sla`, `saml`,
`custom_roles`, `companies`, `advanced_assignment`, `csat_review_notes`, `captain_integration`,
`captain_integration_v2`, `captain_document_auto_sync`, `custom_tools`.

**Mantidas visíveis (3), e o motivo importa:**

- **`disable_branding` FUNCIONA na MIT** — checada em views do núcleo (portal, rodapé da
  documentação, widget) e é **a flag ativa que sustenta o white label**. Esconder as premium em
  bloco teria matado justamente a que mais usamos. Premium ≠ morta.
- **`channel_voice`** e **`advanced_search`**, por decisão do Paulo. Duas notas para quem for
  mexer: `channel_voice` é a **Calling API do WhatsApp da Meta** e não tem relação nenhuma com o
  nosso stack de voz (Twilio + Pipecat, em `app/services/voice/`) — quem confundir vai desligar a
  coisa errada; e `advanced_search` depende de `ChatwootApp.advanced_search_allowed?`, que exige
  `enterprise?` **e** `OPENSEARCH_URL`, então marcar o checkbox não bastaria nem com OpenSearch.
