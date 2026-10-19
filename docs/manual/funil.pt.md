# Funil de vendas, Risk radar e Tarefas: da primeira mensagem ao negócio fechado

Estas três telas trabalham juntas. O **Pipeline** mostra todos os negócios num quadro, etapa por etapa. O **Risk radar** lista os negócios que ficaram quietos e podem morrer sem resposta. **Tasks** guarda o que foi combinado, com prazo. No menu: o **Risk radar** fica perto do topo, **Pipeline** e **Tasks** ficam na seção **CRM**. Dentro de cada conversa, o cartão **Deal** no painel lateral mostra o negócio do cliente.

*Também em: [English](funil.en.md) · [Español](funil.es.md)*

## Antes de começar

1. **Sales Pipeline ligado** na sua conta (um administrador da instalação faz isso no Super Admin, nos recursos da conta). Sem isso, as três telas e o cartão **Deal** não aparecem.
2. **Quem pode fazer o quê.** Administradores e agentes veem e usam o Pipeline, o Risk radar e Tasks, movem negócios e criam tarefas. Só os administradores criam funis e mudam etapas (os botões **Pipeline settings** e **New pipeline** não aparecem para os agentes). Uma tarefa pode ser excluída por quem a criou ou por um administrador.
3. **Os negócios aparecem sozinhos.** Quando um contato escreve pela primeira vez numa caixa onde o bot de IA está ativo, abre-se um negócio para ele na primeira etapa aberta do funil padrão. Um contato tem um negócio aberto por vez. Você também pode clicar em **Create deal** no cartão **Deal** de uma conversa. (Se o bot não está ativo na caixa, confira **Connections**: o negócio não é criado.)
4. **Para a IA mover negócios e dar pontuação** você precisa do Jev ligado (veja o passo 5).
5. **Para o grupo "Bot follows up" do radar** você precisa do follow-up ligado na persona dessa caixa (**Follow up after N hours of silence**, em Bot Personas).

## Passo a passo

### 1. Leia o pipeline
**CRM → Pipeline.** Cada coluna é uma etapa. No topo da coluna você vê quantos negócios ela tem e o valor total. Os negócios de uma coluna vão do movido mais recentemente ao mais antigo.

Cada cartão mostra:
- o título (o nome ou o telefone do contato), o nome do contato quando é diferente, o valor e há quanto tempo está na etapa;
- um **ponto colorido** quando o negócio está em risco: âmbar é "Going cold", vermelho é "Critical" (passe o mouse para ler e ver há quanto tempo foi a última interação);
- um **selo com número**, a pontuação de 0 a 100 (passe o mouse para ver Hot, Warm ou Cold);
- uma caixa âmbar quando o Jev tem uma sugestão (passo 5);
- o link **Open conversation**.

No topo: o **seletor de funil** (a escolha fica no link), o botão **Only at risk** (mostra só os negócios esfriando ou críticos, e desliga o arrastar enquanto está ligado) e, para os administradores, **Pipeline settings** e **New pipeline**.

### 2. Mova um negócio
Arraste o cartão para outra coluna. Você vê "Deal moved to" seguido do nome da etapa.
- Arrastar para uma etapa **Lost** pergunta "Why was this deal lost?". Escreva o motivo e clique em **Mark as lost**. Se cancelar, o cartão volta.
- Arrastar para **Won** não pergunta nada.
- Para reabrir um negócio, arraste-o de volta para uma etapa aberta.
- Cada movimento fica no histórico do negócio: quem moveu (uma pessoa, "The AI" ou o sistema) e, nos perdidos, o motivo.

### 3. Use o cartão Deal dentro da conversa
No painel lateral da conversa, abra **Deal**. Se o contato não tem negócio, você vê "No deal for this contact yet." e **Create deal**. Se tem, você vê (o negócio aberto, ou o mais recente):

| Parte | O que faz |
|---|---|
| Pipeline | Aparece quando a conta tem mais de um funil. Escolher outro move o negócio para a primeira etapa aberta desse funil |
| Stage | Move o negócio. Escolher uma etapa Lost pede o motivo |
| Value | O valor na moeda do negócio (unidades inteiras). Salva ao sair do campo. Negócios novos usam USD, ou BRL nas contas em português |
| Risco e pontuação | O estado ("On track", "Going cold" ou "Critical"), há quanto tempo foi a última interação, quanto a etapa tolera, e a pontuação com os fatores que a formaram |
| History | Os últimos 5 movimentos, com o motivo |
| Next steps | As tarefas pendentes e os próximos compromissos do negócio. Botões **Task** e **Appointment**. Sem nenhum, avisa "No next step yet. Add a task so this deal does not go quiet." |
| Open pipeline | Leva você ao quadro |

Se o Jev tem uma sugestão, uma caixa âmbar mostra "Jev suggests moving to … (NN%)" com **Accept** e **Dismiss**.

### 4. Configure funis e etapas (administradores)
**Pipeline → New pipeline** cria um funil com as etapas-modelo no idioma da conta (em inglês: New lead, Contacted, Qualifying, Proposal sent, Negotiating, Won, Lost). Você pode renomeá-las ou excluí-las. **Pipeline → Pipeline settings** abre a janela das etapas:

| Campo | O que faz |
|---|---|
| Pipeline name | Renomeia o funil |
| Make default | O funil padrão recebe os negócios que abrem sozinhos. Só um é o padrão |
| Delete pipeline | Só dá para excluir um funil vazio e que não seja o padrão |
| Name | O nome da etapa |
| Expected hours | Quanto um negócio pode ficar na etapa antes de contar como frio. Vazio significa 24 |
| Needs a person | Quando a IA move um negócio para esta etapa, a conversa abre para a sua equipe, com uma nota |
| Setas (Move up, Move down) | Mudam a ordem |
| Lixeira (Delete stage) | Só para etapas abertas sem negócios. Uma etapa com negócios não pode ser excluída: mova-os antes |
| Add stage | Cria uma etapa antes de Won e Lost |

Cada campo salva sozinho ao sair dele. **Done** fecha a janela. Todo funil tem exatamente uma etapa **Won** e uma **Lost**; elas não podem ser acrescentadas nem excluídas.

### 5. Deixe o Jev mover os negócios
Abra **Jev** no menu (seção AI agent). Ligue o Jev se estiver desligado (salve a chave da TypeSafe e clique em **Turn Jev on**). No grupo **Sales pipeline**, a atividade **Move the deal along the pipeline** começa em **Observing**: só conta o que faria. Para ele agir, clique em **Let Jev decide**; você pode voltar a observar quando quiser.

Como ele decide (lê cada mensagem do cliente, uma vez por rajada de mensagens):

| Confiança do Jev | O que acontece |
|---|---|
| 80% ou mais | Move o negócio sozinho. O histórico diz "The AI moved it to …" com a porcentagem como motivo |
| Entre 50% e 80% | Deixa uma sugestão no cartão, com **Accept** e **Dismiss** |
| O cliente comprou com clareza ("Won") | Sempre uma sugestão, com qualquer confiança a partir de 50% |
| Uma pessoa moveu o negócio nas últimas 24 horas | Só sugere |

- Ele só move **para a frente**, nunca para trás, e **nunca para Lost**: a IA não sabe o motivo.
- Ele só escolhe entre as etapas que vieram com o modelo (as cinco primeiras, de New lead a Negotiating). As etapas que você mesmo acrescenta só são alcançadas à mão.
- Qualquer movimento feito por uma pessoa apaga uma sugestão pendente.
- Se a IA move um negócio para uma etapa marcada **Needs a person**, a conversa abre para a sua equipe com uma nota ("The deal reached … which needs a person. The conversation was opened for the team.").

### 6. Entenda o risco e a pontuação
**Risco.** A cada 5 minutos o Pipeline recalcula há quanto tempo cada negócio aberto está sem uma interação real: uma mensagem pública para ou do cliente, em qualquer conversa do contato. Notas privadas e mensagens do sistema não contam.

| Estado | Quando | Exemplo com uma etapa de 24 horas esperadas |
|---|---|---|
| On track | Menos tempo que as **Expected hours** da etapa | Menos de 24 h |
| Going cold | As Expected hours ou mais | A partir de 24 h |
| Critical | 3 vezes as Expected hours ou mais | A partir de 72 h |

**Pontuação.** Um número de 0 a 100 feito por fórmula, nunca no palpite, e sempre mostrado com os fatores. Começa em 30 e soma ou subtrai:

| Fator | Pontos |
|---|---|
| Combinou um próximo passo; pediu preço ou proposta; quer comprar ou começar | +12 cada (até 3) |
| Objeção de preço; não é o momento; comparando ou em dúvida | −8 cada (até 3) |
| Descreveu a necessidade; citou um orçamento; citou um prazo; decide ou disse quem decide | +5 cada (até 4) |
| Interação recente / esfriando / sem interação há muito tempo | +10 / −10 / −20 |

A pontuação é **Hot** a partir de 70, **Warm** a partir de 40 e **Cold** abaixo de 40. Enquanto o Jev não achar pelo menos dois sinais na conversa não há pontuação ("No score yet: Jev needs at least two signals from the conversation."). Os sinais vêm do Jev, então ele precisa da atividade do passo 5 em Observing ou Deciding.

### 7. Trabalhe o Risk radar
Abra **Risk radar** no menu. Ele lista os negócios abertos que estão esfriando ou críticos, os mais urgentes primeiro. No topo, etiquetas pequenas contam cada grupo.

| Grupo | Significado |
|---|---|
| Critical | Quieto há 3 vezes o tempo esperado da etapa ou mais |
| Going cold | Quieto há mais que o tempo esperado da etapa |
| Bot follows up | Estaria frio, mas a IA vai retomar a conversa por conta própria |

"Bot follows up" aparece quando: a persona da caixa tem o follow-up ligado, a conversa está num número de WhatsApp conectado por QR que está conectado, ainda está com o bot (sem pessoa atribuída), o bot falou por último, o cliente escreveu nos últimos 7 dias, os follow-ups desse silêncio não se esgotaram e o fuso da caixa não é UTC.

Cada linha mostra: o grupo, o negócio e o valor, o funil e a etapa, "Quiet …", a pontuação, quem está com ele e o follow-up.
- **Quem está com ele:** "With …" (a pessoa atribuída à conversa), "With the AI (…)" ou "No owner".
- **Follow-up:** "The AI follows up …" com a hora prevista, "The AI follows up soon" (a hora já passou e ele espera a janela de envio das 8:00 às 20:00 ou o limite diário do número), ou "No follow-up scheduled".
- Clique na linha para abrir a conversa (ou o Pipeline, se o negócio não tiver).
- **Take over** atribui a conversa a você e a abre, e a IA para de responder. Você vê "The conversation is yours now: the AI stopped answering it." O botão não aparece quando uma pessoa já está com ela.

Acima da lista pode haver blocos que pedem ação:
- Um bloco que diz "N appointments already happened — did the customers show up?": clique em **Mark as done** ou **Did not show up** para cada um.
- Um bloco que diz "N open deals have no next step": negócios sem tarefa pendente nem compromisso futuro, no negócio ou no contato. Clique num deles para abri-lo e acrescentar o que vem a seguir. É o único número que deveria ser zero. Vêm primeiro os mais antigos na etapa, até 50.
- Um bloco que diz "N cases are past their due date", quando a conta usa Cases.

Quando não há nada em risco você vê "No deal at risk. Every open deal had an interaction within its stage's time."

### 8. Guarde o que foi combinado em Tasks
**CRM → Tasks.** Clique em **New task** e preencha:

| Campo | O que é |
|---|---|
| What needs to be done | O título. Obrigatório |
| Due | Data e hora. Opcional |
| Who does it | Uma pessoa, ou "Nobody". Começa sendo você |
| Notes | Até 2.000 caracteres |

Clique em **Save**. Uma tarefa feita aqui não está ligada a nenhum negócio. Para ligar uma tarefa a um negócio, clique em **Task** no cartão **Deal** da conversa.
- Os botões **To do** e **Done** escolhem qual lista você vê, e **Mine** e **Everyone's** de quem são as tarefas. A lista To do se agrupa em **Overdue**, **Today**, **Upcoming** e **No due date**. A lista Done mostra as últimas 100.
- O círculo à esquerda de uma tarefa a marca como feita (**Mark as done**) ou a reabre (**Reopen**). O lápis edita e a lixeira exclui; aparecem ao passar o mouse sobre a tarefa.
- O prazo fica vermelho quando passa. O link da tarefa abre a conversa do negócio dela, ou o contato.

## Quando algo falha ou pausa

| O que você vê | O que significa e o que fazer |
|---|---|
| Pipeline, Risk radar, Tasks ou o cartão Deal não aparecem | O Sales Pipeline não está ligado na conta. Pergunte ao administrador da instalação |
| Um cliente escreveu e nenhum negócio apareceu | A caixa não tem um bot de IA ativo (confira **Connections**), o contato está bloqueado, ou o contato já tem um negócio aberto (procure no quadro). Você pode clicar em **Create deal** na conversa |
| "Could not update the pipeline" | A mudança não foi salva. O quadro recarrega; tente de novo |
| "Only an empty pipeline that is not the default can be deleted. Move its deals or pick another default first." | Mova os negócios dele para outro funil, ou clique antes em **Make default** em outro funil |
| Uma etapa não exclui | Ela tem negócios. Mova-os antes para outra etapa |
| Um cartão volta ao lugar depois de soltar numa etapa Lost | Você cancelou a janela do motivo. Solte de novo e escreva o motivo |
| O Jev não move negócios | Confira: o Jev está ligado e **Move the deal along the pipeline** diz **Deciding**; o destino é uma etapa do modelo e está à frente da atual; uma pessoa não moveu o negócio nas últimas 24 horas (aí ele só sugere); a confiança chegou a 80% |
| "No score yet: Jev needs at least two signals from the conversation." | Normal no começo. Aparece quando o cliente dá mais informação |
| "Could not take over the conversation. Try again." | A atribuição falhou. Tente de novo, ou abra a conversa e atribua a você mesmo |
| Uma linha do radar diz "No follow-up scheduled" | A IA não vai retomar essa conversa: veja as condições de "Bot follows up" no passo 7. Assuma a conversa ou escreva você mesmo ao cliente |
| O botão de excluir de uma tarefa mostra um erro | Só quem criou a tarefa ou um administrador pode excluí-la |
| O Risk radar está vazio | Ótimo: nenhum negócio aberto passou do tempo esperado da etapa |

## Não incluído
- Sem botão "New deal" no quadro: os negócios nascem das conversas. E não há como excluir um negócio pela tela.
- O Jev nunca move um negócio para Lost nem para trás, nem para etapas que você mesmo acrescenta.
- Ninguém é avisado de tarefas vencidas, de sugestões do Jev nem de mudanças no radar: é preciso olhar as telas.
- Sem previsão nem relatórios de receita nestas telas.
- Um negócio aberto por contato. Excluir um contato exclui os negócios e as tarefas dele; juntar dois contatos os passa para o contato que fica.
- O total no topo de uma coluna soma os valores como estão e os mostra na moeda do primeiro negócio; não converte moedas.
