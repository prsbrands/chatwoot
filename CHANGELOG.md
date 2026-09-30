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
