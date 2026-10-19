# Connections: canais, WhatsApp por QR e a saúde do bot de IA

O Connections reúne todos os seus canais numa só lista (WhatsApp por QR, WhatsApp oficial, Instagram, Messenger, site, e-mail e outros) e diz, de cada um, se está conectado e quem responde nele: a IA ou a sua equipe. Fica no menu, na seção **Channels**, como **Connections**. Um ponto vermelho no ícone significa que algo precisa da sua atenção.

*Também em: [English](connections.en.md) · [Español](connections.es.md)*

## Antes de começar

1. **Só os administradores** veem o Connections. Os agentes não veem a tela nem o ponto vermelho.
2. **A linha sobre o bot de IA** (quem responde em cada canal) precisa do **Bot Personas** ligado na sua conta (um administrador da instalação faz isso no Super Admin). Sem isso, a tela ainda lista os canais e se estão conectados, mas não o bot.
3. **Para conectar um número de WhatsApp por QR** a conta precisa do **WhatsApp Sessions** ligado no Super Admin, e a instalação precisa ter o gateway de WhatsApp configurado (**Super Admin → Settings → WhatsApp Gateway**, com o endereço e a chave do gateway). Use um **número dedicado** e tenha à mão o celular com WhatsApp para ler o código.
4. **Para a IA responder num canal** você precisa de uma persona (menu **Personas**, seção AI agent) e de um bot de agente (**Settings → Bots**).

## QR ou API oficial?

| | WhatsApp por QR | WhatsApp API oficial (Meta) |
|---|---|---|
| Como conecta | Você lê um código QR com o celular, como ao vincular um aparelho no WhatsApp | Pela Meta (WhatsApp Business "Quick setup with Meta" ou WhatsApp Cloud), 360Dialog ou Twilio |
| Onde você gerencia | **Settings → Integrations → WhatsApp Sessions** (também pelo botão **WhatsApp by QR code**) | Na própria caixa, **Settings → Inboxes** (também pelo botão **WhatsApp official API**) |
| O que tem aqui | Campanhas do Outreach, lembretes de compromisso e mensagens de falta, o follow-up da IA quando o cliente fica quieto e o alerta quando a sessão cai | O menu **Campaigns** padrão. Fora da janela de 24 horas depois da última mensagem do cliente, o WhatsApp só permite templates aprovados, então o que está à esquerda não roda nela |

Na lista, o tipo aparece como "WhatsApp · QR code", "WhatsApp · Official API (Meta)" ou "WhatsApp · 360dialog".

## Passo a passo

### 1. Leia a tela
- No topo, uma linha vermelha diz quantos canais precisam de atenção: "N channels need attention: customers there may be getting no answer."
- Os canais ficam agrupados em **WhatsApp** e **Other channels**, com os que precisam de atenção primeiro.
- Cada linha mostra o nome do canal, o tipo e o número de telefone, uma etiqueta **Connected** ou **Disconnected**, e uma linha sobre o bot (passo 4). Clique no nome para abrir as configurações da caixa.
- Um botão **Fix** aparece nas linhas que precisam de atenção (passo 5).
- A etiqueta **Disconnected** só existe para os canais que podem perder a conexão: WhatsApp por QR, WhatsApp configurado com o quick setup da Meta, Instagram, Messenger, TikTok e e-mail com Google ou Microsoft. Os outros (site, Telegram, SMS e assim por diante) sempre mostram Connected.

### 2. Conecte um número por QR
1. Em **Connections**, clique em **WhatsApp by QR code**. Abre o **WhatsApp Sessions**.
2. Clique em **New session** e preencha:

| Campo | O que é |
|---|---|
| Session name | De 3 a 50 caracteres: letras minúsculas, números e hifens (por exemplo `sales-line`) |
| Inbox | Deixe "Create a new inbox for this session (recommended)". Escolha uma caixa existente só para reaproveitá-la: a conexão dela é reapontada para esta sessão. Se achar uma caixa que parece ser o mesmo número, oferece **Reuse this inbox** |
| Answer with an agent bot | Só aparece se você tem bots de agente. Deixe ligado e escolha o **Agent bot** para a IA responder neste número |

3. Clique em **Create**. Abre a janela **Pair WhatsApp** com um código QR (primeiro "Preparing QR code…").
4. No celular, abra WhatsApp → Settings → Linked devices → Link a device, e leia o código.
5. Quando aparecer "Number connected! The session is ready." clique em **Close**.
6. Volte ao **Connections** e confira a linha: **Connected** e "AI answers as …" (passo 4).

A lista de sessões mostra **Session**, **Status**, **Phone**, **Inbox** e **Actions**:

| Status | Significado |
|---|---|
| Created, Initializing | Iniciando |
| Waiting for QR scan | Esperando você ler o código |
| Authenticating | A leitura foi aceita |
| Connected | Funcionando |
| Disconnected | A sessão caiu (passo 7) |
| Action required, Failed | A sessão precisa de ajuda: clique em **Pair** de novo |

| Botão | O que faz |
|---|---|
| Pair | Mostra o código QR para ler. Aparece enquanto a sessão não está Connected. É também como se reconecta |
| Start | Inicia de novo uma sessão Disconnected |
| Stop | Para uma sessão Connected |
| Log out | Desconecta o número da sessão |
| Lixeira | Exclui a sessão (veja o passo 7 antes de usar) |

### 3. Conecte a API oficial do WhatsApp
Em **Connections**, clique em **WhatsApp official API**. Abre a criação de uma caixa de WhatsApp em **Settings → Inboxes**, onde você escolhe o provedor (WhatsApp Business, WhatsApp Cloud, Twilio ou 360Dialog) e segue as telas. Os passos da própria Meta não são cobertos aqui.

### 4. Veja se a IA está respondendo
A linha embaixo de cada canal diz quem responde nele:

| O que você lê | Significado |
|---|---|
| AI answers as … | Tudo certo: o bot está ligado e tem uma persona |
| No AI — your team answers | Não há bot neste canal. Não é falha se é isso que você quer |
| Voice calls, answered by the voice agent | Um número de voz. Quem responde é o agente de voz, não o bot de texto |
| The AI bot is on but has no persona, so it does not answer | **Problema** (vermelho). A caixa chama o bot, mas não há persona para responder |
| The AI bot's saved credentials are out of date, so it does not answer | **Problema** (vermelho). O bot e a persona foram salvos com credenciais diferentes |
| A persona is set, but the AI bot is not on this channel, so it does not answer | **Problema** (vermelho). A persona existe, mas a caixa não chama o bot |

Ligar o bot pelas configurações da própria caixa não configura a persona. Faça sempre por **Bot Personas → Channels**.

### 5. Conserte um canal
O **Fix** leva você aonde o problema se resolve:
- **Problema do bot:** para **Bot Personas → Channels**. Na linha do canal escolha a **Persona** e o **Agent bot**, ligue **Bot active** e clique em **Save**. Salvar conecta o bot à caixa e grava de novo as credenciais dele, o que resolve os três problemas do passo 4. O botão Save só funciona com uma persona e um bot escolhidos. Se disser que não há bots de agente, crie um em **Settings → Bots**.
- **WhatsApp por QR que caiu:** para o **WhatsApp Sessions** (passo 7).
- **Outro canal que caiu:** para as configurações da caixa, onde você o reconecta.

A lixeira de uma linha remove a rota da persona daquele canal.

### 6. O ponto vermelho no menu
O ponto vermelho no ícone do **Connections** aparece quando algum canal está **Disconnected** ou tem um dos três problemas do bot. Ele é calculado quando a página carrega, então depois de consertar algo recarregue a página ou abra o Connections. Só os administradores o veem.

### 7. Quando uma sessão QR cai
O sistema confere as sessões a cada 5 minutos. Quando uma sessão não está Connected em duas conferências seguidas (então leva de 5 a 10 minutos para notar, para evitar alarme falso quando o gateway reinicia), a caixa é marcada:
- o ponto vermelho, e **Disconnected** na linha do Connections;
- um aviso nas configurações da caixa: "This WhatsApp number is disconnected. Replies and follow-ups are not delivered until you scan the QR code again on the same connection." com o botão **Scan the QR code**;
- um e-mail para os administradores da conta;
- os follow-ups da IA pulam essa caixa, e as campanhas do Outreach nesse número pausam (veja o manual do Outreach).

Para reconectar:
1. Clique em **Fix** no Connections (ou em **Scan the QR code** nas configurações da caixa). Você cai no **WhatsApp Sessions**.
2. Na sessão desse número clique em **Pair** e leia o código QR.
3. Quando disser "Number connected! The session is ready." o alerta some na hora.

**Reconecte sempre na mesma sessão.** Criar uma sessão nova para o mesmo número faz uma caixa duplicada, sem as conversas nem o bot de antes. Se você realmente precisa de uma sessão nova, o **New session** oferece **Reuse this inbox** quando acha a caixa antiga.

Excluir uma sessão (lixeira, depois **Delete**) remove a conexão com o gateway, mas mantém a caixa e as conversas; o bot para de responder ali. Para trazê-la de volta, crie uma **New session** e reaproveite a caixa antiga.

## Quando algo falha ou pausa

| O que você vê | O que significa e o que fazer |
|---|---|
| "OpenWA gateway is not configured. Set the gateway URL and API key in Super Admin → Settings → WhatsApp Gateway." | A instalação ainda não tem os dados do gateway. Pergunte ao administrador dela |
| "Could not reach the OpenWA gateway" | O gateway não respondeu. Tente de novo em um minuto; se persistir, avise o administrador da instalação |
| "Session name must be 3-50 characters, lowercase letters, numbers and hyphens only." | Corrija o **Session name** |
| "The selected inbox must be an API channel inbox." | Você escolheu uma caixa que não pode ser reaproveitada. Deixe "Create a new inbox for this session" |
| "Session not found for this account." | Essa sessão é de outra conta ou não existe mais. Recarregue a lista |
| "Bot route not created: persona not found in the bot layer." | A configuração automática procura uma persona com um nome fixo escolhido pela instalação, e a sua conta não tem nenhuma com esse nome. O número conectou, mas o bot não vai responder: vá em **Bot Personas → Channels** e defina a persona, o bot e **Bot active** |
| "Bot route not created: Supabase env vars are missing. Add the route manually." ou "Bot route creation failed. Add the route manually." | A mesma solução: **Bot Personas → Channels** |
| O código QR fica em "Preparing QR code…" | Espere alguns segundos: ele continua consultando sozinho. Se não aparecer, feche a janela e clique em **Pair** de novo. Se o status for Failed ou Action required e persistir, avise o administrador da instalação |
| A linha diz Disconnected mas o celular está bem | O gateway perdeu a sessão. Clique em **Pair** e leia de novo |
| "This inbox belongs to a Twilio voice route…" ao salvar um canal | Essa caixa é só o registro das ligações de voz: quem responde é o agente de voz. Não coloque um bot de texto nela |
| Chegam mensagens mas a IA não responde | Leia a linha do bot no Connections (passo 4) e aplique o **Fix** |
| Um número novo conectou mas o bot está mudo | A linha do bot mostra o problema. Faça o passo 5 |

## Não incluído
- A tela não conecta Instagram, Messenger, site nem e-mail: eles são criados em **Settings → Inboxes**. O Connections só os mostra e os conserta.
- As sessões QR nunca se reconectam sozinhas: quando o WhatsApp corta o vínculo, alguém precisa ler o código de novo.
- O ponto vermelho e as linhas não são ao vivo: atualizam quando a página carrega.
- Os agentes não recebem o alerta; só os administradores (na tela e por e-mail).
- Sem histórico de mensagens nem métricas por canal nesta tela.
- O status Connected não prova que as mensagens chegam nos canais que não conseguem informar uma queda (site, Telegram, SMS).
