# Cases: acompanhe o que o cliente pediu até resolver

O Cases registra o que um cliente pediu e não dá para resolver na hora: uma dúvida que depende de alguém da empresa, um problema, uma solicitação, uma reclamação. Cada caso tem número, responsável, prazo e desfecho, e pode reunir várias conversas do mesmo cliente. Fica no menu, em **CRM → Cases**.

*Também em: [English](casos.en.md) · [Español](casos.es.md)*

## Antes de começar

1. **Cases ligado** na sua conta (um administrador da instalação faz isso no Super Admin, nos recursos da conta, chave **Cases**). Sem isso não aparecem o item do menu, o bloco **Cases** do painel da conversa nem a aba **Cases** do contato.
2. **Quem pode fazer o quê.**

| | Agentes | Administradores |
|---|---|---|
| Ver, abrir, editar e trabalhar qualquer caso | Sim | Sim |
| Ver **Case metrics** | Sim | Sim |
| **Case settings** (tipos, prazos, detalhes, IA, prefixo) | Não | Sim |
| **Delete case** | Não | Sim |

3. **Tipos de caso.** Na primeira vez que a conta abre o Cases, ela recebe cinco tipos no idioma da conta (português, espanhol ou inglês; qualquer outro idioma recebe inglês). Renomeie, mude ou acrescente os seus em **Case settings** (passo 1).

| English | Español | Português | Prazo | Prioridade padrão |
|---|---|---|---|---|
| Question | Duda | Dúvida | 24 h | Normal |
| Problem | Problema | Problema | 8 h | High |
| Request | Solicitud | Solicitação | 48 h | Normal |
| Complaint | Reclamo | Reclamação | 4 h | High |
| Billing | Financiero | Financeiro | 24 h | Normal |

4. **Os prazos contam horas corridas**, não horário comercial, a partir do momento em que o caso é aberto. Aparecem no fuso horário do seu navegador.
5. **Para a IA abrir casos e responder pelo assistente** você também precisa de: uma *persona* de IA respondendo pelo menos uma caixa (AI agent → Personas), o **Jev** ligado com a chave dele (AI agent → Jev) e o administrador da instalação mantendo publicado o workflow "CortexGen Caso" no n8n. O passo 6 e o passo 7 explicam cada um. O resto do Cases funciona sem nada disso.
6. **Números que vale conhecer.**

| O quê | Valor |
|---|---|
| Número do caso | `PREFIXO-ANO-0001`, que volta a contar do 1 a cada ano (por exemplo `CAS-2026-0001`) |
| Prefixo | De 1 a 8 letras ou dígitos, sempre em maiúsculas; `CAS` até você mudar |
| Casos na lista | De 100 em 100, depois **Show more** |
| Descrição, nota, "What was done" | até 5.000 caracteres |
| Mensagem enviada pelo assistente | até 2.000 caracteres |
| "When is it this type?" | até 500 caracteres |
| Confiança mínima para a IA escolher um tipo | 80% |
| Respostas enviadas pelo assistente | até 5 por minuto para a conta toda |

## Passo a passo

### 1. Defina os tipos de caso (administradores)
**Cases → Case settings.**

- **Number prefix:** digite as letras e clique em **Save**. Só muda os casos novos; os números já dados ficam como estão.
- **Case types:** a lista mostra cada tipo com o prazo, a prioridade, a quantidade de detalhes e se a IA o abre ou se o cliente é avisado. Use as setas para mudar a ordem, o lápis (**Edit type**) para editar e a lixeira (**Delete type**) para apagar. Um tipo que já tem casos não pode ser apagado: desligue **Available for new cases**.
- **New type** (ou o lápis) abre uma janela com:

| Campo | O que faz |
|---|---|
| Name | Como o tipo aparece em todo lugar |
| Color | A bolinha que identifica o tipo na lista e no quadro |
| Due in (hours) | Horas inteiras, a partir de 1. Contadas desde a abertura de um caso deste tipo. Em branco: **No due date**. Mudar não move o prazo dos casos já abertos |
| Default priority | Low, Normal, High ou Urgent, usada ao abrir o caso |
| Default assignee | A pessoa que recebe os casos novos deste tipo (Nobody: ninguém) |
| Available for new cases | Desligado: o tipo deixa de aparecer ao abrir um caso e a IA não o usa. Os casos existentes o mantêm |
| When the AI notices this kind of request | **The AI does not open this type**, **The AI opens it and keeps helping the customer** ou **The AI opens it and hands the conversation to the team** (passo 7) |
| When is it this type? | Aparece quando a IA está ligada para o tipo. Diga com suas palavras o que entra neste tipo, até 500 caracteres (passo 7) |
| Tell the customer the case number and when it is resolved | Envia ao cliente dois avisos na conversa do caso (passo 8) |
| Details of this type | Informações que o seu negócio precisa para esse tipo de caso. **Add detail** cria um: **Label**, **Kind** (Text, Number, Date, List ou Yes / no), **Options** (só para List, separadas por vírgula, pelo menos uma) e **Required to resolve**. **Remove detail** apaga |

Sobre os detalhes: o tipo (Kind) de um detalhe não pode ser mudado depois de salvo. Renomear o Label muda só o nome na tela. Remover um detalhe o esconde, mas os casos que já tinham um valor o mantêm nos dados.

**Exemplo: um tipo "Reclamação de garantia".** Name: Reclamação de garantia. Due in: 48. Default priority: High. Default assignee: a chefe do suporte. Details: "Número do pedido" (Text, required to resolve), "Problema" (List: Defeituoso, Item errado, Atraso) e "Foto recebida" (Yes / no). IA: **The AI opens it and keeps helping the customer**, com "When is it this type?": *Um produto chegou danificado ou errado, ou parou de funcionar dentro da garantia*. Aviso ao cliente: ligado.

### 2. Abra um caso
Há três maneiras:

- **Por uma conversa:** no painel da direita, no bloco **Cases** (lista os casos ativos do cliente), clique em **New case**. O caso nasce ligado a essa conversa, com o cliente já preenchido.
- **Por um contato:** abra o contato, aba **Cases** (lista também os casos resolvidos e cancelados), clique em **New case**. O caso fica sem conversa: ligue uma depois (passo 4).
- **Pela página Cases:** clique em **New case** e procure o cliente por nome, telefone ou e-mail (pelo menos 2 letras). **Change** permite escolher outro cliente.

Na janela **New case** preencha:

- **Type** (o primeiro tipo ativo já vem escolhido) e **Title** ("What does the customer need?"); **Description** é opcional.
- **Priority** e **Assignee** vêm do tipo e podem ser mudados.
- Embaixo aparecem os **detalhes** do tipo. Os obrigatórios só são exigidos ao resolver, não ao abrir.

Clique em **Open case**. O negócio aberto do cliente que foi atualizado mais recentemente é ligado ao caso automaticamente.

### 3. Encontre os seus casos
Em **Cases** você vê primeiro os ativos, com o prazo mais próximo no topo (os vencidos primeiro, e os casos sem prazo no fim).

- **Active / Resolved / Canceled** escolhem qual grupo você vê. Resolved e Canceled mostram primeiro os alterados mais recentemente.
- **Everyone / Mine / Unassigned** filtram por responsável.
- **Overdue** mostra só os atrasados. Os menus **All types** e **All priorities** filtram por tipo e prioridade.
- A busca (**Number, title or customer**) ignora acentos.
- Os ícones **List** e **Board** (só em Active) alternam entre uma lista e três colunas: Open, In progress e Waiting for customer.
- Cada caso mostra número, tipo, situação, título, cliente, prioridade, responsável e prazo (**Due ...**, ou **Overdue since ...** em vermelho, ou **Waiting for the customer** enquanto o prazo está pausado).

Um **número vermelho** em **Cases** no menu conta os casos vencidos da conta toda, atualizado a cada minuto (um caso que espera o cliente não conta como vencido). O **Risk radar** também mostra no topo "N cases are past their due date", com um link para cada um.

### 4. Trabalhe um caso
Clique em um caso para abri-lo.

- **No topo:** número, tipo, situação, desfecho (depois de resolvido), **Overdue** e **Opened by the AI** quando valem. O lápis (**Edit**) ao lado do título muda o título e a descrição (**Save** / **Cancel**).
- **Botões por situação:**

| Situação | Botões |
|---|---|
| Open | **Start**, **Wait for customer**, **Resolve**, **Cancel case** |
| In progress | **Wait for customer**, **Resolve**, **Cancel case** |
| Waiting for customer | **Start**, **Resolve**, **Cancel case** |
| Resolved ou Canceled | **Reopen** (volta para In progress) |

- **Coluna da direita:** **Assignee**, **Priority**, **Type** e **Due date** mudam assim que você escolhe. No prazo, digite a data e a hora e saia do campo; se esvaziar, o prazo é removido. Mudar o tipo depois não recalcula prioridade, responsável nem prazo. Embaixo: o **Customer** (abre o contato), o **Deal** e **Conversations**.
- **Waiting for customer pausa o prazo.** Quando você clica em **Start** de novo, o prazo anda o tempo em que o caso ficou parado.
- **Details:** preencha as informações do tipo e clique em **Save**. Os marcados com * são obrigatórios para resolver.
- **History:** escreva uma nota interna e clique em **Add note**. As notas são só da equipe; o cliente nunca as vê. Embaixo, em ordem de tempo, tudo o que aconteceu: quem mudou o quê e quando, notas, o que a IA fez (autor **AI**), eventos automáticos (**System**) e o que o cliente respondeu (**Customer**).
- **Conversations:** cada conversa ligada abre ao clicar. As outras conversas do mesmo cliente aparecem como **Link conversation #id**; clique em uma para somá-la ao caso.

### 5. Resolva ou cancele um caso
- **Resolve:** primeiro preencha e salve os detalhes obrigatórios; senão a tela diz "Fill in ... before resolving the case." ou "Save the details before resolving the case." Na janela, escolha o **Outcome** e, se quiser, escreva **What was done** (aparece em destaque no caso).

| Outcome | Use quando |
|---|---|
| Solved | A necessidade do cliente foi atendida (é o padrão) |
| Not applicable | Não havia nada a fazer |
| Duplicate | A mesma solicitação já existe em outro caso |
| No response from the customer | O cliente nunca respondeu |

- **Cancel case:** para um caso aberto por engano ou que não é mais necessário. Você pode escrever **Why it was canceled**. Ele fica guardado na lista **Canceled**.
- **Delete case** (lixeira, administradores): apaga o caso e todo o histórico depois de uma confirmação. Prefira cancelar; apagar não tem volta.

### 6. Responda ao cliente pelo assistente
Use quando a equipe sabe a resposta mas você quer que a IA a diga, no idioma e no tom do cliente. O bloco **Reply through the assistant** aparece quando o caso está ativo e tem uma conversa ligada.

1. Escreva o que o cliente precisa saber (por exemplo "The replacement ships on Monday and arrives in 3 business days.").
2. Clique em **Send answer**, ou em **Ask the customer** se você precisa de algo dele (um número de pedido, uma foto).
3. Em cerca de um minuto a IA publica na conversa, como o bot daquela caixa, reescrevendo o seu texto no idioma e no tom do cliente, sem acrescentar nenhum fato.

O resultado aparece em **History** com um destes estados:

| Estado | Significado |
|---|---|
| waiting to be sent | Ninguém pegou ainda. É normal por até um minuto. Se ficar muito tempo, a conversa pode estar numa caixa sem bot, ou o workflow está parado: avise o administrador da instalação |
| being sent | A IA está escrevendo e publicando |
| sent | Já está na conversa. O texto que saiu também aparece no histórico |
| could not be sent | A publicação falhou. O autor é avisado; escreva de novo ou responda você mesmo na conversa |

Com **Ask the customer**, o caso vai para **Waiting for customer** quando a pergunta é enviada. Quando o cliente responde (texto, foto ou arquivo, em qualquer conversa daquele cliente), a resposta é guardada em **History**, o caso volta para **In progress** e o responsável é mencionado. Isso só acontece depois de uma pergunta enviada com **Ask the customer**; um caso que você pôs em **Wait for customer** na mão não volta sozinho.

Se a conta atingiu o teto mensal de IA, ou a IA não responde, o seu texto sai exatamente como você escreveu.

### 7. Deixe a IA abrir casos
Quando um cliente relata um problema, faz uma solicitação ou uma reclamação, ou pede algo que só uma pessoa pode decidir, a IA pode abrir o caso e dar o número ao cliente. Para configurar (administradores):

1. O **Jev** precisa estar ligado (AI agent → Jev, com a chave da TypeSafe). No cartão do Jev, a atividade **Notice what only the team can solve** (grupo **Open cases for the team**) vem em **Deciding**. Se estiver em **Observing** ou pausada, a IA não abre casos.
2. Em **Case settings**, edite cada tipo que você quer que a IA use e escolha em **When the AI notices this kind of request**:
   - **The AI opens it and keeps helping the customer:** o caso é aberto, a IA diz o número e continua respondendo o resto que o cliente perguntar, enquanto a equipe trabalha no caso.
   - **The AI opens it and hands the conversation to the team:** o caso é aberto, a IA diz o número, deixa uma nota privada com um resumo e a conversa vai para a equipe. A IA para de respondê-la.
3. Em **When is it this type?** descreva, com suas palavras, o que entra no tipo. Exemplo: *Um produto chegou danificado ou errado, ou parou de funcionar dentro da garantia.* A IA escolhe entre os seus tipos usando o nome e esse texto. Seja específico: dois tipos com descrições parecidas a confundem.

O que esperar:

- A IA só abre um caso quando tem pelo menos 80% de certeza do tipo. Se não, responde como sempre.
- O caso nasce antes da resposta, então a resposta pode trazer o número. O título é a primeira frase do cliente e a descrição é a mensagem inteira. O caso mostra **Opened by the AI**.
- Se o cliente já tem um caso ativo do mesmo tipo, não se abre um segundo caso: a mensagem nova é somada àquele caso como uma nota da IA e a conversa é ligada.
- A IA também conta ao cliente em que etapa estão os casos abertos dele, com palavras simples, sem dar datas e sem dizer que algo está resolvido.
- Rede de segurança: se a IA diz "vou verificar com a equipe" mas nenhum caso foi aberto, o Jev segura essa resposta e passa a conversa para a equipe.
- O responsável é avisado (veja "Quem é avisado"). Se o caso não tem responsável, é avisado o dono do negócio aberto do cliente ou, se não houver, o primeiro administrador da conta.

### 8. Avise o cliente automaticamente
Ligue **Tell the customer the case number and when it is resolved** no tipo. O cliente passa a receber, na conversa do caso e no idioma dele (espanhol, português ou inglês; qualquer outro recebe inglês):

| Quando | Mensagem |
|---|---|
| Caso aberto | Registramos sua solicitação com o número CAS-2026-0001. A equipe já está cuidando dela e vamos avisar quando estiver resolvida. (em inglês: "We logged your request as ...", em espanhol: "Registramos tu solicitud con el número ...") |
| Caso resolvido | Sua solicitação CAS-2026-0001 foi resolvida. Se precisar de mais alguma coisa, é só escrever aqui. (em inglês: "Your request ... has been resolved ...", em espanhol: "Tu solicitud ... fue resuelta ...") |

O aviso de abertura não é enviado nos casos abertos pela IA, porque a própria resposta dela já dá o número. Quando um aviso não consegue sair, o **History** diz o motivo:

| Mensagem no History | Significado |
|---|---|
| the case has no conversation | Ligue uma conversa ao caso |
| this inbox does not deliver messages | A caixa (canal API sem webhook) não consegue enviar mensagens ao cliente |
| outside the reply window of the channel | A janela de resposta do canal fechou (WhatsApp oficial, depois de 24 h) |

### 9. Acompanhe como os casos estão indo
**Cases → Case metrics.** Escolha **Last 7 days**, **Last 30 days** ou **Last 90 days**. Você vê os totais e os mesmos números **By type** e **By assignee** ("Nobody" reúne os sem responsável).

| Coluna | O que conta |
|---|---|
| Opened | Casos abertos no período |
| By the AI | Desses, quantos a IA abriu |
| Resolved | Casos resolvidos no período |
| Time to resolve | Tempo médio entre abrir e resolver, em horas (o tempo esperando o cliente conta) |
| On time | Parte dos casos resolvidos que foram resolvidos dentro do prazo (casos sem prazo ficam de fora; "—" quando não há nenhum) |
| Active now | Casos abertos, em andamento ou esperando o cliente hoje |
| Overdue now | Casos ativos com o prazo vencido hoje (em vermelho) |

## Quem é avisado

| O que aconteceu | Quem | Como |
|---|---|---|
| Um caso é atribuído a outra pessoa (ao abrir ou ao editar) | O novo responsável | Nota privada na conversa do caso mencionando a pessoa (chega nas notificações dela). Não é enviada se você atribui a si mesmo |
| A IA abriu um caso | O responsável, ou o dono do negócio aberto do cliente, ou o primeiro administrador | A mesma nota privada |
| O cliente respondeu uma pergunta enviada com **Ask the customer** | O responsável, ou o dono do negócio, ou o primeiro administrador | A mesma nota privada |
| A IA não conseguiu enviar uma resposta escrita pela equipe | Quem escreveu (ou o responsável, o dono do negócio, o primeiro administrador) | A mesma nota privada |
| Um caso vence | Ninguém é avisado um a um | Número vermelho no menu e o **Risk radar** |

Um caso sem conversa não avisa ninguém: só aparece em **Mine** e no número vermelho.

## Quando algo falha ou para

| O que você vê | O que fazer |
|---|---|
| "Fill in ... before resolving the case." / "Save the details before resolving the case." | Preencha os detalhes obrigatórios do tipo e clique em **Save** no caso |
| "CAS-... is resolved: start not allowed" (ou outra situação e ação) | Alguém mudou o caso nesse meio tempo. Recarregue a página e confira a situação |
| "CAS-... has no conversation with the customer" | Ligue uma conversa ao caso antes de usar **Reply through the assistant** |
| "This type has cases and cannot be deleted. Turn it off instead." | Edite o tipo e desligue **Available for new cases** |
| "Could not save. Try again." | Tente de novo; se repetir, confira os valores (uma data, um número, uma opção da lista) |
| A resposta fica em **waiting to be sent** | A conversa está numa caixa sem bot, ou o workflow "CortexGen Caso" está parado. Avise o administrador da instalação, ou responda na conversa |
| **could not be sent** | A IA não conseguiu publicar na conversa. Confira se a caixa está conectada e escreva de novo |
| A IA nunca abre um caso | Confira: **Cases** ligado na conta; Jev ligado, com a atividade **Notice what only the team can solve** em **Deciding**; o tipo com a IA ligada e **Available for new cases** ligado; uma persona respondendo naquela caixa |
| A IA abriu um caso do tipo errado | Melhore **When is it this type?** e o nome dos tipos |
| O cliente não recebeu o aviso | Veja a tabela do passo 8 |
| O número vermelho não some | Ele conta os casos ativos vencidos da conta toda; resolva ou cancele, ou mude o prazo deles |

## Não incluído
- Sem uma página para o cliente acompanhar o caso: o cliente só recebe os dois avisos do passo 8.
- Prazos em horário comercial: eles contam horas corridas.
- Sem lembrete nem escalonamento automático quando um caso vence (só o número vermelho e o **Risk radar**).
- A IA não preenche os detalhes do tipo; quem preenche é a equipe.
- Sem distribuição automática de casos por carga ou rodízio: o responsável é o padrão do tipo ou quem você escolher.
