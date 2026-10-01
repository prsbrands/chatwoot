# Changelog — CortexGen Chat

Versão própria do CortexGen Chat, independente da versão do Chatwoot em que ele se
apoia (a base aparece em cada versão). A versão atual fica em `VERSION_CORTEXGEN`.

**Como versionar:** todo deploy em produção sobe a versão aqui, no `VERSION_CORTEXGEN`
e numa tag git `cg-vX.Y.Z` no commit que foi ao ar.
- **MINOR** (0.9.0): recurso novo que o usuário percebe.
- **PATCH** (0.8.1): correção ou ajuste sem recurso novo.
- **1.0.0** fica reservada para o funil de vendas, quando o sistema passa a ser um CRM completo.

Cada entrada diz o que muda para quem usa. O detalhe técnico e as armadilhas ficam no
`HANDOFF.md`.

---

## [0.14.0] — 2026-10-01 · base Chatwoot 4.18.0

**O Jev move o negócio no funil (bloco 3b)**
- Nova atividade no cartão do Jev: **Move the deal along the pipeline**. A cada mensagem do cliente (uma vez por rajada), o Jev diz em que etapa o negócio está.
- Só para frente, só entre etapas com passo do agente, e nunca para a perda.
- Em **Deciding**:
  - com 80% ou mais, move sozinho, e o histórico mostra "IA" e a confiança;
  - entre 50% e 80%, e sempre para "fechou", deixa uma **sugestão** no card do Kanban e no card Deal da conversa, com Accept e Dismiss.
- Depois que uma pessoa mexe no negócio, o Jev só sugere por 24 h.
- Etapa marcada como "precisa de pessoa" (Pipeline settings): quando a IA move o negócio para ela, a conversa abre para a equipe.
- Em **Observing** (o padrão), só registra o que faria; o cartão do Jev mostra quantas vezes moveria.

## [0.13.0] — 2026-10-01 · base Chatwoot 4.18.0

**Vários funis por conta**
- Admin cria funis em **Pipeline → New pipeline**. O funil novo vem com as etapas-modelo no idioma da conta, que dá para renomear ou apagar.
- Em **Pipeline settings**: renomear o funil, torná-lo padrão e apagar (só funil vazio e que não seja o padrão).
- Seletor de funil no topo do Kanban. A escolha fica no link.
- No card **Deal** da conversa, com mais de um funil, dá para levar o negócio para outro funil; ele vai para a 1ª etapa aberta, e a mudança fica no histórico.
- O negócio automático (1ª mensagem numa inbox com bot) continua nascendo no funil padrão.

## [0.12.0] — 2026-10-01 · base Chatwoot 4.18.0

**Funil de vendas (bloco 3a)**
- Menu **Pipeline**: o funil da conta em colunas, com arrastar entre as etapas e o total por coluna. Ir para a etapa de perda pede o motivo.
- Funil padrão no idioma da conta: Ventas na conta em espanhol, Vendas em português, Sales em inglês. São 5 etapas abertas, mais ganho e perda.
- Admin edita as etapas em **Manage stages**: nome, ordem, horas esperadas na etapa e "precisa de pessoa".
- Cada negócio tem contato, conversa de origem, valor e moeda (BRL nas contas em português), e status (aberto, ganho ou perdido) que segue a etapa.
- Todo contato que escreve numa inbox com bot ganha um negócio na 1ª etapa; mensagens em rajada abrem um só.
- Card **Deal** no painel da conversa: criar o negócio, trocar a etapa, pôr valor e ver o histórico de quem moveu.
- Liga e desliga pela flag **Sales Pipeline** (Super Admin), por conta.

## [0.11.1] — 2026-10-01 · base Chatwoot 4.18.0

- WhatsApp Sessions explica, no cartão, no cabeçalho e ao excluir, que um número caído se reconecta com **Pair** na mesma sessão, mantendo a inbox, as conversas e o bot.
- Em **New session**, um nome que lembra uma inbox de WhatsApp sem sessão (os mesmos 6 últimos dígitos, ou o nome dentro do nome da inbox) mostra o aviso com **Reuse this inbox**, em vez de criar uma duplicada.

## [0.11.0] — 2026-10-01 · base Chatwoot 4.18.0

**O Chatwoot vigia as conexões de WhatsApp por QR**
- A cada 5 minutos confere cada conexão do OpenWA. Conexão caída por 10 minutos:
  - a inbox ganha o alerta vermelho na barra lateral;
  - a configuração da inbox mostra "This WhatsApp number is disconnected", com o botão **Scan the QR code**;
  - os admins recebem e-mail;
  - o follow-up para nessa inbox.
- Ler o QR de novo na mesma conexão tira o alerta na hora e mantém a inbox, o histórico e a rota do bot.
- Excluir uma conexão desliga o bot da inbox dela; excluir uma inbox apaga a rota dela em Bot Personas, sem deixar canal fantasma.

## [0.10.0] — 2026-09-30 · base Chatwoot 4.18.0

**Follow-up quando o cliente some (WhatsApp por QR)**
- Na persona: "Follow up after N hours of silence" (vazio = desligado) e quantos follow-ups por silêncio (padrão 2).
- Só retoma conversa pendente com o bot, em que o bot falou por último e o cliente escreveu nos últimos 7 dias. Humano atribuído, contato bloqueado ou cliente que respondeu encerram a série.
- O Jev decide se vale retomar ("vou pensar" vale; "obrigado, era só isso" não): atividade nova no cartão do Jev. Sem Jev, quem decide é a IA da persona.
- A IA da persona escreve a retomada com o contexto ("passou 1 dia, você ia pensar no plano Pro"), em bolhas com "digitando".

**Anti-ban dos números conectados por QR**
- Envio só das 8h às 20h no fuso da inbox (Inboxes → Business hours). Inbox sem fuso não recebe follow-up.
- Teto diário pela idade do número: 20, 50, 100 e depois 200. Até 3 por número a cada 15 min, com 20–45 s entre um e outro.
- Texto quase igual aos últimos follow-ups do número é vetado.

## [0.9.0] — 2026-09-30 · base Chatwoot 4.18.0

**Passagem para humano com briefing**
- Toda vez que o bot passa a conversa, fica uma nota privada no idioma do cliente com:
  - por que o bot passou;
  - o que o cliente quer;
  - o que o bot já fez;
  - compromissos e pendências;
  - as 3 últimas mensagens do cliente, literais.
- Vale para os quatro caminhos: palavra-chave/limite de turnos/filtro do modelo, o Jev antes de responder, a resposta retida pelo Jev e o opt-out.

**Respostas em bolhas no WhatsApp, Instagram e Messenger**
- A resposta sai em até 4 mensagens, com "digitando" e uma pausa pelo tamanho de cada uma. No widget continua uma mensagem só.

**Opt-out que bloqueia**
- "stop", "baja", "no me escriban más", "me tira da lista"… bloqueiam o contato, põem a etiqueta `opt-out` e abrem a conversa para a equipe. O bot não responde mais a contato bloqueado, também no OpenWA.
- Para desfazer: desbloquear na tela do contato.
- Campanhas de WhatsApp e SMS pulam contato bloqueado (entra com a próxima imagem do Rails).

## [0.8.0] — 2026-09-30 · base Chatwoot 4.18.0

**Jev para a equipe**
- Botão **"Suggest with CortexGen AI"** ao lado das etiquetas e da prioridade de cada conversa: sugere até 3 etiquetas da conta e a prioridade.
- Condição **CortexGen AI** nas automações, descrita em texto livre ("o cliente quer cancelar").
- As duas usam a chave TypeSafe **da própria conta**, sem e-mail, telefone e CPF no que é enviado, e o custo entra no cartão do Jev.
- Liga e desliga no bloco "In your team's inbox" do cartão; desligar o Jev desliga as duas.
- Conta PRS: 11 etiquetas com descrição (orçamento, agendar-reuniao, agente-ia…) e a automação de exemplo "reclamação ou cancelamento", que marca, sobe a prioridade, abre a conversa e atribui a um atendente.

## [0.7.0] — 2026-09-30 · base Chatwoot 4.18.0

**Atualização da base (Chatwoot 4.16.2 → 4.18.0 + 13 dias)**
- Segurança: dois alertas do Chatwoot (desvio nas checagens do login, execução de macro sem permissão), XSS, rate-limit do login, SSRF em mídia de SMS.
- Canais: login empresarial do Instagram, botões do Messenger, o widget não cria contato para robôs, correções de e-mail (SMTP sem IMAP, imagens inline, assunto, encaminhar).
- Recursos: macro em várias conversas, 2FA obrigatório por conta, empresas (CRM básico), checagem de entrega de e-mail no Super Admin.
- Incidente: ~3 min com a lista de conversas fora do ar no deploy, por uma migration com versão repetida (ver `HANDOFF.md`).

## [0.6.0] — 2026-09-30 · base Chatwoot 4.16.2

**Jev — decisões rápidas em volta do bot**
- Cartão **"Jev — fast decisions"** em Settings → Integrations → AI Providers: chave TypeSafe por conta, conferida ao salvar, consentimento na primeira vez, e cada atividade em Observing, Deciding ou Paused.
- Antes do LLM, o Jev decide:
  - que parte da base de conhecimento enviar;
  - que modelo usar (leve ou forte, configurados na persona);
  - se a mensagem nem precisa de resposta ("ok, gracias");
  - se a conversa vai para um humano (pediu atendente, cliente irritado, opt-out, tentativa de manipulação).
- Depois do LLM, o Jev confere a resposta antes de enviar (responde ao cliente? promete o que não pode? vaza instruções? quebra alguma regra da conta?).
- O Jev nunca derruba o bot: se falhar ou passar de 1,5 s, o fluxo segue como antes. Números de 7 e 30 dias no cartão.

## [0.5.1] — 2026-08-19 · base Chatwoot 4.16.2

- O token que o bot usa para ler o histórico passa a ser gravado sozinho ao ligar o bot num canal; toda conta nova antes exigia um passo manual.
- Execuções vermelhas falsas no n8n eliminadas: o Guard passa a ler a inbox também em `conversation_updated`.
- O Super Admin deixa de mostrar 11 flags premium que não funcionam na edição MIT.

## [0.5.0] — 2026-08-13 · base Chatwoot 4.16.2

**Várias contas no mesmo sistema**
- Segunda conta em produção (dagente).
- O bot resolve segredo, token de leitura e token de resposta por conta.
- Sessões de WhatsApp isoladas por conta.
- Checkboxes de features por conta no Super Admin da edição Community.
- Não é mais possível ligar um bot de texto numa inbox de voz.
- Formulário público de pedido de demo que dispara ligação, com a rota escolhida pelo DDI do telefone.

## [0.4.0] — 2026-08-10 · base Chatwoot 4.16.2

**O bot passa a ligar, e a marca fica completa**
- O bot também faz ligações, pelo botão **Call demo** na conversa.
- Derruba a chamada que cai no correio de voz e desliga sozinho depois da despedida.
- A qualificação do lead passa a sair da leitura da chamada inteira.
- O limite de fim de turno virou campo da persona. Latência mediana de 1,1 a 2,2 s.
- Arte oficial, tema verde e o nome "CortexGen Chat" em todos os 57 idiomas.
- E-mail: saída pelo Resend, entrada pelo Mailgun.
- O webhook do bot passa a exigir a assinatura do Chatwoot.
- Persona e base de conhecimento passam a ser da conta.

## [0.3.0] — 2026-08-09 · base Chatwoot 4.16.2

**Agente de voz e Twilio**
- Integração Twilio por conta: números, inbox de SMS, chamadas roteadas para o softphone do atendente.
- Agente de voz (Pipecat + Deepgram + ElevenLabs): uma persona atende o telefone.
- Cada chamada vira conversa e contato, com métricas de custo e espera.
- O assistente de escrita passa a se chamar **CortexGen AI**.
- Super Admin governa a pilha de bots da instância.

## [0.2.0] — 2026-08-08 · base Chatwoot 4.16.2

**Camada de bots no painel**
- Editores de persona, modelo e base de conhecimento.
- Chaves de IA por conta, com catálogo de modelos sincronizado e reserva entre provedores.
- Ligar o bot num canal numa tela só.

## [0.1.0] — 2026-08-07 · base Chatwoot 4.16.2

**CortexGen Chat nasce**
- White label do Chatwoot, só na edição Community (MIT).
- Sessões de WhatsApp (OpenWA) gerenciadas pelo painel.
- Login do Facebook for Business.
