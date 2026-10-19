# Outreach: campanhas no seu número de WhatsApp por QR

O Outreach envia uma mensagem para uma lista de pessoas pelo seu número de WhatsApp por QR, num ritmo que protege o número de ser banido. Fica no menu, em **CRM → Outreach**.

*Também em: [English](outreach.en.md) · [Español](outreach.es.md)*

## Antes de começar

1. **Um número de WhatsApp por QR conectado.** Ele precisa estar conectado por QR em **Connections** (não a API oficial do WhatsApp). Se a sessão cair, as campanhas pausam sozinhas.
2. **O fuso horário do número.** Abra a caixa desse número em Settings → Inboxes → Business hours e escolha o fuso. As campanhas não começam numa caixa em UTC, porque o horário de envio ficaria errado.
3. **Outreach ligado** na sua conta (um administrador da instalação faz isso no Super Admin). Só os administradores da conta veem e usam o Outreach.
4. **Idade do número.** Um número novo envia pouco: 20 mensagens por dia nos 3 primeiros dias, 50 até o dia 7, 100 até o dia 14 e 200 depois. A campanha nunca passa desse limite, mesmo que você configure um maior.

## Passo a passo

### 1. Crie a campanha
**Outreach → New campaign.** Dê um nome, escolha o número e escreva a primeira mensagem. O resto se ajusta na página da campanha, enquanto ela ainda é um **Draft** (rascunho).

### 2. Escreva a mensagem
- **Versões:** até 3 textos. Eles se alternam de uma pessoa para a outra, para nem todos receberem as mesmas palavras. Use **Add another version**.
- **Variáveis:** `{name}` (primeiro nome), `{full_name}`, `{company}` e qualquer coluna do seu arquivo, escrita em minúsculas e sem acento (a coluna "Cidade" vira `{cidade}`). Quem não tem o dado que uma versão precisa fica de fora da campanha, assim ninguém recebe "Olá {name}".
- **Opções sorteadas:** `{Oi|Olá|E aí}` escolhe uma das palavras a cada envio.
- **Bolhas:** uma linha em branco começa uma nova mensagem do WhatsApp (até 4). Entre as bolhas o número mostra "digitando…".
- **Cold list (lista fria):** marque quando as pessoas nunca falaram com você. A campanha passa a usar só metade do limite diário do número.
- **Opt-out line (linha de saída):** texto colocado no fim de toda mensagem, por exemplo "Responda PARAR para não receber mais mensagens." Quem responder com uma palavra de parada é bloqueado e nunca mais recebe campanha.

Clique em **Save**. Se a campanha estava pronta, ela volta a rascunho e você prepara a lista de novo.

### 3. Defina o ritmo
Tudo aqui só pode deixar a campanha mais lenta que os limites do próprio número, nunca mais rápida.

| Campo | O que faz | Padrão |
|---|---|---|
| Starts / Ends at (hour) | Janela de envio, no fuso do número | 8 às 20 |
| Days | Dias da semana permitidos | seg a sáb |
| Gap between messages | Segundos sorteados entre os dois valores, nunca menos de 15 | 20 a 45 |
| Per hour, at most | Teto por hora desta campanha | 30 |
| Per day, at most | Teto por dia desta campanha (vazio: o limite do número) | vazio |
| Messages before a break | Depois dessa quantidade de mensagens a campanha descansa | 10 |
| Break (min) | Descanso sorteado entre os dois valores | 5 a 15 |

Uma campanha que chega num limite não falha: espera e continua na próxima janela.

### 4. Defina a lista
Escolha **Spreadsheet** (planilha) ou **CRM contacts** e clique em **Use this list**. Usar outra lista substitui a anterior.

**Spreadsheet.** CSV, XLSX ou ODS, até 10.000 linhas, com os títulos das colunas na primeira linha. (Arquivos XLS antigos: salve antes como XLSX.)
- Escolha o arquivo. As primeiras linhas aparecem.
- Diga qual coluna é o **telefone** (obrigatório), o **nome** e a **empresa**. O Outreach tenta adivinhar pelos títulos.
- **Country code (código do país):** acrescentado aos números escritos sem ele (507 por padrão). Número com "+" ou "00" é usado como está. Número comprido sem código do país é recusado em vez de adivinhado.
- As outras colunas podem ser usadas como variáveis na mensagem.
- As pessoas do arquivo não viram contatos até responderem. Uma lista fria não enche o seu CRM.

**CRM contacts.** Escolha uma etiqueta e/ou uma caixa. Contatos sem telefone aparecem como de fora.

### 5. Revise e comece
1. **Send a test to yourself:** digite o seu número e clique em **Send test**. Você recebe a primeira versão, com os dados da primeira pessoa da lista. Não conta na campanha.
2. **Prepare the list.** O Outreach confere todo mundo e mostra quantos **vão receber a mensagem** e quantos **ficam de fora e por quê** (tabela abaixo).
3. **Start sending.** A campanha começa na hora.

### 6. Acompanhe, pause ou cancele
Na página da campanha:
- **Pause** para depois da mensagem que está sendo enviada. **Resume** continua.
- **Cancel campaign** para de vez; as pessoas que ainda esperavam são canceladas.
- Os resultados se atualizam sozinhos: **Sent**, **Replied**, **Waiting**, **Failed**, **Asked to stop** e **Left out**, com a lista de pessoas e um filtro por situação.
- A taxa de resposta conta quem respondeu entre quem recebeu a mensagem. Uma resposta só conta para a campanha nas 72 horas seguintes ao envio.

## Quem fica de fora (e por quê)
A conferência roda ao preparar a lista **e de novo logo antes de cada mensagem**, porque alguém pode ter pedido para parar nesse meio tempo.

| Motivo | Significado |
|---|---|
| Asked to stop receiving messages | O contato está bloqueado |
| In the exclusion list | Entrou em Outreach → Exclusion list |
| No phone number / Not in a valid format | O número não pode ser usado |
| Same number as another person on the list | Só o primeiro recebe |
| Already waiting in another campaign | Uma campanha por vez por pessoa |
| Received a campaign in the last 30 days | Evita insistir |
| Open conversation with your team | Campanha nunca interrompe uma conversa em andamento |
| Missing data the message uses | Por exemplo, `{name}` para quem não tem nome |

## Lista de exclusão
**Outreach → Exclusion list.** Números que nenhuma campanha vai tocar (o seu contador, um concorrente, um cliente que você só liga). Cole os números, um por linha ou separados por vírgula. Não é o mesmo que alguém pedir para parar: as pessoas dessa lista **continuam sendo atendidas normalmente** se escreverem para você.

## O que acontece quando alguém responde
A resposta chega na sua caixa como qualquer outra mensagem, e o bot do número responde como sempre. A campanha marca a pessoa como **Replied**. Se a pessoa nunca tinha escrito para você, a conversa só aparece na sua caixa quando ela responde; antes disso não há nada na lista de Conversations.

## Quando uma campanha pausa sozinha
O menu mostra um número vermelho e a campanha explica o motivo:
- **The WhatsApp session of the number is disconnected:** reconecte o número em Connections e clique em **Resume**.
- **Three sends in a row failed:** confira o número e a conexão e clique em **Resume**. Quem teve o envio falhado não é reenviado automaticamente.
- **The number has no WhatsApp session:** a conexão foi removida; conecte de novo.

Se **Start sending** disser que a caixa precisa de um fuso horário, defina como explicado no começo. Se disser que ninguém está esperando para receber, prepare a lista de novo.

## Boas práticas para proteger o seu número
- Comece pouco com um número novo e deixe os limites por idade trabalharem.
- Prefira quem já conhece você. Para listas frias, marque **Cold list**, escreva uma mensagem curta dizendo quem você é e use a linha de saída.
- Use 2 ou 3 versões do texto e opções sorteadas, e evite links na primeira mensagem.
- Mantenha os intervalos e descansos padrão. Não rode várias campanhas grandes no mesmo número no mesmo dia.
- Olhe **Asked to stop** e **Failed**. Muitos de qualquer um dos dois indicam que a lista ou a mensagem precisam de ajuste.

## Não incluído
- Sem marcas de "entregue" e "lida" (o WhatsApp por QR não informa).
- Um número por campanha, sem rodízio entre números.
- Sem campanhas pela API oficial do WhatsApp nem SMS aqui; o menu **Campaigns** padrão continua com elas.
- Sem acompanhamento automático para quem não respondeu.
