# Agenda: compromissos, jornada de atendimento, Google Calendar e agendamento pela IA

A Agenda é o calendário onde sua equipe marca compromissos com os clientes e vê quem atende cada um. Ela pode compartilhá-los com o Google Calendar, e a IA pode marcar sozinha no chat. Fica no menu, perto do topo, como **Agenda**. Os tipos de agendamento e a jornada estão em **Agenda settings** (o ícone de engrenagem no alto, à direita, da página da Agenda).

*Também em: [English](agenda.en.md) · [Español](agenda.es.md)*

## Antes de começar

1. **Não há nada para ligar.** A Agenda está ativa em todas as contas (não existe chave no Super Admin). Administradores e agentes a veem.
2. **Fusos horários.** A grade usa o fuso do seu navegador. A **jornada** de cada pessoa tem o próprio fuso (por exemplo America/Bogota). Os horários que a IA oferece aos clientes, e a data e a hora dos lembretes, usam o fuso de quem atende.
3. **O Google Calendar é opcional**, e precisa que o administrador da instalação cadastre uma vez o cliente OAuth do Google, em **Super Admin → Settings → Google Calendar** (campos "Google Calendar client ID" e "Google Calendar client secret"; o endereço a autorizar no Google é `<seu endereço>/google_calendar/callback`). Não é a tela "Google", usada para o Gmail e o login. Enquanto isso não for feito, o cartão do Google não aparece na página da Agenda. Depois, cada pessoa conecta a própria conta do Google.
4. **Para a IA marcar compromissos** é preciso mais: veja o passo 8.
5. **Quem pode fazer o quê:**

| Ação | Administrador | Agente |
|---|---|---|
| Ver a agenda de toda a equipe, marcar e editar compromissos, mudar a situação deles | Sim | Sim |
| Excluir um compromisso | Qualquer um | Só os que criou ou atende |
| Criar, editar e excluir tipos de agendamento | Sim | Não (vê a lista) |
| Editar a jornada | A de qualquer pessoa | A própria |
| Conectar o Google Calendar | O próprio | O próprio |

## Passo a passo

### 1. Leia a Agenda
- **Day** e **Week** trocam a visão. A semana começa na segunda-feira. As setas avançam e voltam, **Today** volta para hoje e o título mostra o período.
- O seletor no alto, à direita, escolhe de quem você vê os compromissos: **My agenda**, **Whole team** ou uma pessoa.
- Cada compromisso é um bloco com o título, a hora e o nome do cliente (e quem atende, quando você não está vendo **My agenda**). Compromissos que se sobrepõem dividem a largura.
- Os blocos cinza **Busy** são horas que a pessoa já tem ocupadas no Google Calendar, e **Busy all day** aparece no topo do dia. Só aparecem para quem tem o Google conectado.
- A linha vermelha é a hora atual.

### 2. Marque um compromisso
Três jeitos: clique num horário vazio da grade (arredonda para a meia hora); clique em **New appointment** (começa na próxima meia hora); ou, numa conversa de uma conta com Sales Pipeline, abra o cartão **Deal** e clique em **Appointment**, que já preenche o cliente e o negócio.

| Campo | O que é |
|---|---|
| What | O título. Obrigatório. Por exemplo "Demo call, visit, consultation…" |
| Type | Um dos seus tipos de agendamento, ou "No type". Só aparece se você criou tipos |
| When | Data e hora. Obrigatório |
| How long | 15, 30, 45, 60, 90 ou 120 minutos |
| Free times that day | Aparece depois de escolher um tipo. Clique num horário para preencher **When** |
| Who attends | A pessoa que vai atender. Começa sendo você |
| Who is being attended | O cliente. Busque por nome, telefone ou e-mail (a partir de 2 letras). O × remove |
| Where | Endereço, link de videochamada ou telefone |
| Notes | Até 2.000 caracteres |

Clique em **Save** (ele habilita quando **What** e **When** estão preenchidos).
- Escolher um **Type** preenche a duração, o local (se estiver vazio) e, nos compromissos novos, quem atende por padrão.
- **Free times that day** mostra os horários livres desse tipo para quem atende no dia de **When**. Você sempre pode definir a hora à mão: marcar à mão não confere sobreposição.
- Um tipo com **Needs confirmation** cria o compromisso como **Waiting for confirmation**. Nos outros casos ele fica **Confirmed**.
- Quando o tipo cria um link do Google Meet e o Google já sincronizou o compromisso, ao abri-lo aparece **Join the Google Meet**.

### 3. Acompanhe cada compromisso até o fim
Clique num compromisso. No topo você vê a situação e os botões das outras situações, mais o **Delete**.

| Situação | Botão que define | Como aparece |
|---|---|---|
| Waiting for confirmation | (a situação inicial dos tipos que exigem) | Âmbar tracejado |
| Confirmed | **Confirm** | Azul |
| Done | **Mark as done** | Verde-azulado |
| Did not show up | **Did not show up** | Vermelho, riscado |
| Cancelled | **Cancel** | Cinza, riscado |

- Os compromissos Waiting e Confirmed ocupam o tempo da pessoa: nenhum horário livre é oferecido por cima deles. Os outros liberam o tempo.
- Os lembretes só são enviados para compromissos **Confirmed**.
- Se a conta tem Sales Pipeline, o **Risk radar** lista os compromissos que terminaram nos últimos 30 dias sem desfecho, com os botões **Mark as done** e **Did not show up**. Use-os: eles também disparam a mensagem de falta (passo 7).

### 4. Crie os tipos de agendamento
**Agenda settings → Appointment types → New type** (administradores). O lápis edita um tipo e a lixeira o exclui (os compromissos já marcados ficam, sem tipo). Cada tipo mostra a duração, quem atende por padrão e etiquetas como "Needs confirmation", "The AI books this type" ou "Not offered".

| Campo | O que faz | Limites e padrão |
|---|---|---|
| Name | O nome que as pessoas escolhem. Obrigatório | |
| Duration (min) | Quanto dura | 5 a 1.440. Padrão 60 |
| Gap before (min), Gap after (min) | Folga livre mantida em volta de cada compromisso | 0 a 240. Padrão 0 |
| Minimum notice (min) | Com quanta antecedência a partir de agora dá para marcar | 0 a 43.200. Padrão 120 |
| Bookable up to (days ahead) | Até quantos dias à frente dá para marcar | 1 a 365. Padrão 60 |
| Who attends by default | A pessoa cuja agenda vale para os horários livres. "Whoever books" deixa em aberto | |
| Where | Endereço, link de videochamada ou telefone | |
| Needs confirmation | Os compromissos novos desse tipo começam como Waiting for confirmation | Desligado |
| Offered when booking | Desligado esconde o tipo do seletor **Type** ("Not offered") | Ligado |
| The AI can book this type | Deixa a IA marcar esse tipo no chat (passo 8). Precisa de alguém em **Who attends by default** | Desligado |
| Create a Google Meet link | O evento do Google ganha uma sala do Meet. Precisa do Google de quem atende conectado | Desligado |
| When booked, move the deal to | Move o negócio aberto do cliente para a etapa escolhida. Só aparece se a conta tem funis | Do not move the deal |
| Remind the customer | Mensagem de lembrete antes do compromisso (passo 7) | Desligado |
| Message when the customer does not show up | Mensagem para os compromissos a que o cliente faltou (passo 7) | Vazio |

**Como os horários livres são calculados.** Para um tipo e uma pessoa, a Agenda oferece horas que: ficam dentro da jornada da pessoa; começam depois de agora mais o **Minimum notice** e dentro de **Bookable up to**; se sucedem a cada **Duration** (um tipo de 60 minutos em 9:00–18:00 oferece 9:00, 10:00 … 17:00); e, com as folgas antes e depois, não encostam num compromisso Waiting ou Confirmed dessa pessoa nem numa hora ocupada do Google Calendar dela. Quem não tem jornada não tem horários livres.

**Mover o negócio ao marcar** só o move para a frente, dentro do mesmo funil, e só enquanto o negócio está aberto. O histórico do negócio registra quem moveu (a pessoa ou a IA).

### 5. Defina a jornada
**Agenda settings → Working hours.** Os administradores escolhem a pessoa no seletor no alto, à direita, da seção; os agentes definem a própria.
1. Preencha **Time zone** como em America/Bogota ou America/Sao_Paulo.
2. Ligue cada dia em que a pessoa atende e defina o início e o fim. Um dia desligado diz "Off". Há uma única faixa por dia.
3. Clique em **Save working hours**. Você verá "Working hours saved."

Nada existe até você clicar no botão. O segunda a sexta, das 09:00 às 18:00, que você vê na primeira vez é só uma sugestão: se não salvar, a pessoa não tem horários livres.

### 6. Conecte o Google Calendar
1. Na página da Agenda, no cartão **Google Calendar**, clique em **Connect Google**.
2. Na tela do Google escolha a conta e permita todas as permissões pedidas (ver e editar eventos na sua agenda).
3. Você volta para a Agenda com "Google Calendar connected." e o cartão diz "Connected as" seguido do seu e-mail do Google, e que seus compromissos vão para a agenda principal dele.

Cada pessoa conecta a própria conta. O que é compartilhado:

| Direção | O que acontece |
|---|---|
| Da Agenda para o Google | Cada compromisso vai para a **agenda principal** da conta do Google de quem atende: título, notas (como descrição), local e hora. Um compromisso Waiting for confirmation vai como provisório, um Cancelled é cancelado, um excluído some, e trocar quem atende o leva para a agenda da nova pessoa. É enviado um instante depois de você salvar. |
| Do Google para a Agenda | Só as horas ocupadas, e só da agenda principal. Aparecem como blocos cinza **Busy** e são descontadas dos horários livres. Eventos marcados como Livre (disponível) e eventos cancelados não contam. Eventos do Google não viram compromissos, e compromissos enviados pela Agenda não são contados duas vezes. Mudanças no Google podem levar até 2 minutos para aparecer na grade. |

- **Use another account** conecta outra conta do Google. Os eventos já enviados ficam na conta antiga.
- **Disconnect** para a sincronização. Não revoga a permissão no Google nem apaga os eventos já criados. Para o Google esquecer o acesso, revogue-o na sua conta do Google.

### 7. Lembretes e faltas (WhatsApp por QR)
**Lembrete.** Em um tipo, ligue **Remind the customer**, defina **How many hours before** (de 0,25 a 168) e escreva a **Reminder message**. Ela já vem com um texto que você pode editar. O cliente a recebe no WhatsApp quando tudo isto é verdade:
- o compromisso está **Confirmed** e tem um contato;
- o contato tem uma conversa num número de WhatsApp conectado por QR (a conversa do próprio compromisso, ou a conversa mais recente do contato num número QR);
- o contato não está bloqueado.

É enviado uma única vez. A conferência roda a cada 5 minutos, então pode chegar alguns minutos atrasado. Não é enviado pela API oficial do WhatsApp (fora da janela de 24 horas só passam templates aprovados).

**Falta.** Escreva um texto em **Message when the customer does not show up**. Quando alguém clica em **Did not show up** (no compromisso ou no Risk radar), o cliente recebe essa mensagem do mesmo jeito. Vazio significa que nada é enviado. O exemplo em cinza do campo é só uma sugestão: digite o seu texto para usá-lo. Se o cliente responder e o agendamento pela IA estiver configurado, a IA oferece novos horários.

Marcadores que você pode usar nas duas mensagens:

| Marcador | Vira |
|---|---|
| `{name}` | O primeiro nome do cliente |
| `{date}` | O dia e o mês, como 21/10 |
| `{time}` | A hora, em 24 horas, no fuso de quem atende |
| `{type}` | O nome do tipo de agendamento |
| `{link}` | O link do Google Meet, ou o local se não houver link |

### 8. Deixe a IA marcar
A IA oferece horários no chat e marca o que o cliente aceita. Para isso, confira tudo:
1. **Um bot está respondendo nessa caixa.** Em **Connections** a linha diz "AI answers as …".
2. **O Jev está ligado e a atividade de agendamento está decidindo.** Abra **Jev** no menu (seção AI agent), salve a chave da TypeSafe com **Check and save** e clique em **Turn Jev on** (você precisa concordar com o envio das mensagens para a TypeSafe). No grupo **Book appointments**, a atividade **Notice a wish to book** deve dizer **Deciding** (ela começa assim). Se disser Observing, clique em **Let Jev decide**.
3. **Um tipo de agendamento com** **The AI can book this type** ligado, **Offered when booking** ligado e **Who attends by default** escolhido. Se vários tipos tiverem a chave da IA ligada, só o primeiro por nome é oferecido.
4. **Quem atende tem jornada salva** (passo 5). Sem ela a IA não encontra horários livres.
5. **Recomendado:** quem atende tem o Google conectado, para que as horas ocupadas também bloqueiem a IA e o evento seja criado na agenda dela.
6. **Nenhuma regra que proíba confirmar compromissos**, no prompt da persona ou em "Your rules" de **Check the reply before sending** do Jev. Isso contradiz o agendamento.

**O que o cliente vive.**
1. O cliente diz que quer marcar, pergunta quais horários estão livres ou escolhe uma hora.
2. Se ele ainda não disse, a IA pergunta qual dia e qual período do dia (manhã ou tarde) funcionam melhor.
3. Ela oferece até 3 horários livres dos próximos 14 dias, no idioma do cliente e no fuso de quem atende.
4. O cliente escolhe um (ou pede o dele, como "terça às 9"). Se estiver livre, o compromisso é marcado naquele momento e a IA o confirma com dia da semana, data e hora.
5. Se o tipo cria um link do Google Meet, uma última mensagem com o link vem depois da confirmação.
6. Se o cliente pede para cancelar, o compromisso é cancelado com as palavras do cliente como motivo. Se pede para mudar, o horário novo é marcado primeiro e só depois o antigo é cancelado.

**O que você vê.**
- O compromisso na Agenda, com um título como "Consultation — Ana Lopez" (nome do tipo e depois nome do cliente), ligado ao contato, à conversa e ao negócio aberto do cliente. Fica **Confirmed**, ou **Waiting for confirmation** se o tipo exigir (clique em **Confirm**).
- Uma nota privada na conversa que menciona quem atende, para que essa pessoa receba a notificação de sempre (sino, e-mail ou push, conforme as preferências dela). Cancelamentos feitos pelo cliente também deixam uma nota.
- O evento no Google Calendar de quem atende, e o negócio movido para a etapa que você escolheu no tipo.

Se uma pessoa assumir a conversa, a IA para de responder e de marcar nela.

## Quando algo falha ou pausa

| O que você vê | O que significa e o que fazer |
|---|---|
| Não há cartão do Google Calendar na Agenda | A instalação ainda não tem o cliente do Google. Peça ao administrador dela que preencha **Super Admin → Settings → Google Calendar** |
| "Could not start the Google connection." | Tente de novo. Se persistir, peça ao administrador que confira o cliente do Google |
| "The Google connection was cancelled." | Você fechou ou recusou a tela do Google. Clique em **Connect Google** de novo |
| "Google did not grant access to the calendar. Connect again and allow every permission." | Você desmarcou uma permissão. Conecte de novo e deixe todas marcadas |
| "Could not connect Google Calendar. Try again." | A conexão não se completou. Tente de novo. Se ficar mais de 10 minutos na tela do Google, você cai na página inicial sem mensagem nenhuma: comece de novo |
| O cartão fica vermelho: "Google stopped accepting the connection with …. Connect again to keep syncing." | Clique em **Connect again**. Enquanto estiver vermelho nada sincroniza e as horas ocupadas do Google são ignoradas. Os compromissos salvos nesse meio tempo não são enviados depois: abra cada um, mude algo (por exemplo as notas) e clique em **Save** |
| A conexão vence mais ou menos a cada 7 dias, ou só algumas pessoas conseguem conectar | O app do Google ainda está em modo de teste. O administrador da instalação precisa publicá-lo no Google Cloud |
| "Could not read N Google Calendar(s) right now; their busy times are missing." | O Google não respondeu. A Agenda aparece sem essas horas ocupadas. Recarregue em alguns minutos |
| "Google Calendar did not answer: its busy times were left out." | Os horários livres podem incluir horas que estão ocupadas no Google. Confira à mão antes de marcar |
| "No free time that day for this type. Pick another day, or set the time by hand." | Confira se quem atende tem jornada salva, se o dia está ligado, o fuso, o **Minimum notice** e o **Bookable up to**, as folgas e os compromissos Waiting ou Confirmed do dia |
| "Could not save the appointment. Try again." | O compromisso não foi salvo. Confira **What** e **When** e tente de novo |
| Excluir não funciona | Só um administrador, quem criou o compromisso ou quem o atende pode excluí-lo |
| Um compromisso não está no Google | O Google da pessoa que **atende** (não de quem criou) precisa estar conectado e o cartão não pode estar vermelho. Depois abra o compromisso, mude algo e clique em **Save** para enviá-lo de novo |
| O lembrete não chegou | Confira: o compromisso está **Confirmed**; tem um contato; o contato tem uma conversa num número QR que está conectado; o contato não está bloqueado; **Remind the customer** está ligado; e já está dentro das horas anteriores. Não é enviado pela API oficial do WhatsApp |
| A IA não oferece horários | Percorra a lista do passo 8, ponto por ponto. Se o Jev estiver lento ou falhar, o bot funciona como antes e não marca |
| A IA diz "Sorry, that time was just taken. Would one of these work for you?" (ou o equivalente no idioma do cliente) | Normal: alguém ocupou o horário entre a oferta e a resposta. Ela lista até 3 outros horários, ou diz que alguém da equipe vai escrever |
| A IA diz que não há horários livres nos próximos 14 dias | Quem atende está com a agenda cheia ou não tem jornada. Ela avisa o cliente que alguém da equipe vai entrar em contato |
| Uma resposta ficou retida e a conversa foi para a sua equipe, com a nota "tells the customer the appointment is booked, but nothing was booked in the Agenda" | A rede de segurança pegou uma confirmação que não marcou nada. Marque à mão e responda ao cliente |
| A IA diz que a equipe vai cuidar, sem oferecer horários | Não foi possível ler a agenda naquele momento. Tente de novo; se repetir, avise o administrador da instalação |

## Não incluído
- Sem página pública para os clientes marcarem sozinhos: o cliente marca só conversando com a IA.
- Só Google Calendar (sem Outlook nem Apple), só a agenda principal da conta, e eventos do Google nunca são importados como compromissos.
- Lembretes e mensagens de falta só saem pelo WhatsApp conectado por QR. Sem lembretes por e-mail ou SMS, e sem lembretes para a equipe.
- Uma pessoa por compromisso: sem salas, grupos nem compromissos recorrentes.
- Marcar à mão nunca confere sobreposição.
- Uma única faixa de horas por dia na jornada.
- A IA marca um único tipo, dentro dos próximos 14 dias (no máximo 40 horários).
- Os erros de sincronização com o Google não aparecem na tela.
