# AI memory: o que a IA lembra de cada cliente

O AI memory é um resumo curto e uma lista de fatos sobre cada cliente que a IA mantém atualizados sozinha depois das conversas, e que lê antes de responder, em qualquer canal. Você pode ler, corrigir e completar. Fica no bloco **AI memory** do painel da direita de qualquer conversa, e na aba **AI memory** do contato (Contacts → abra um contato).

*Também em: [English](memoria-ia.en.md) · [Español](memoria-ia.es.md)*

## Antes de começar

1. **Não há nenhuma chave para ligar.** O painel faz parte da instalação e está disponível para todas as contas. A IA só o preenche para clientes que falaram por uma caixa respondida por um bot de IA.
2. **Quem pode usar.** Agentes e administradores veem e editam a memória de qualquer cliente.
3. **Uma IA respondendo a caixa.** Uma *persona* de IA precisa responder pelo menos uma caixa (AI agent → Personas, aba **Channels**). O administrador da instalação também precisa manter publicado o workflow "CortexGen Memória" no n8n: é ele que escreve a memória.
4. **Quando a IA escreve.** Uma conversa é lida quando a última mensagem do cliente tem pelo menos 30 minutos (por isso a memória aparece uns 30 a 40 minutos depois do fim de uma conversa, um pouco mais se houver muitos clientes esperando), a conversa teve atividade nos últimos 7 dias e tem mensagens do cliente que não foram lidas antes. Várias conversas do mesmo cliente são lidas uma de cada vez, e só a parte nova é lida.
5. **Custo.** A IA usa o modelo leve da persona (ou o modelo normal da persona, se ela não tiver um leve). Conta no **AI usage**, como **Customer memory**, e no teto mensal de IA da conta. Uma conta que atingiu o teto é pulada, e a memória dela deixa de atualizar até o mês seguinte ou até o teto ser aumentado.
6. **Números que vale conhecer.**

| O quê | Valor |
|---|---|
| O workflow roda | a cada 10 minutos |
| Clientes atualizados por rodada | até 5 |
| Mensagens lidas por rodada | até 40 novas, mais 6 anteriores para contexto |
| Resumo | até 1.500 caracteres (a IA escreve até 5 frases) |
| Cada fato | até 300 caracteres (a IA os escreve curtos, de umas 15 palavras no máximo) |
| Fatos novos por rodada | até 10 |
| Fatos por cliente | quando o total passa de 30 (os seus incluídos), a IA apaga os fatos dela mais antigos que não estejam fixados |
| O que a IA lê antes de responder | o resumo e os fatos, até 1.500 caracteres no total |
| Nova tentativa depois de uma rodada que falhou | depois de 1 hora |

## Passo a passo

### 1. Abra a memória de um cliente
- **Numa conversa:** no painel da direita, abra o bloco **AI memory** (por padrão vem logo depois do bloco do negócio; a seta abre e fecha).
- **Num contato:** Contacts → abra o contato → aba **AI memory**.

A memória pertence ao contato e é a mesma em todos os canais. Se a mesma pessoa são dois contatos diferentes (por exemplo um número de WhatsApp e um e-mail), cada um tem a sua própria memória até você juntar os contatos.

Se ainda não foi escrito nada, o painel diz "Nothing remembered yet. The AI fills this in when a conversation has been quiet for 30 minutes, and reads it before answering in any channel."

### 2. Leia
- **Summary:** como as coisas estão agora, em poucas frases: o que o cliente está pedindo no momento, o que foi combinado, o que está pendente. Embaixo, "Updated by the AI on ..." dá a data da última atualização feita pela IA.
- **Facts:** uma linha curta cada um sobre o que continua verdadeiro do cliente: quem é, o negócio dele, orçamento, decisões, objeções, preferências (horário, canal, tom), o que comprou e compromissos com data ou responsável. Um fato marcado **team** foi escrito ou corrigido por uma pessoa. Um alfinete colorido marca um fato fixado. Os fixados vêm primeiro, depois os mais antigos.

### 3. Acrescente um fato
Digite no campo **Add a fact about this customer** e tecle Enter, ou clique no botão **+** (**Add fact**). Um fato que você escreve fica marcado **team**.

### 4. Corrija ou apague um fato
Passe o mouse sobre o fato:

- O lápis (**Edit fact**) permite reescrevê-lo; tecle Enter ou clique em **Save** (**Cancel** desiste). Um fato que você edita passa a **team**.
- A lixeira (**Delete fact**) apaga na hora, sem pedir confirmação.

### 5. Fixe um fato
Clique no alfinete ao lado do fato (**Pin: the AI reads it first and never changes it**). Para desfazer, clique de novo (**Unpin**). Use para o que nunca pode ser esquecido nem mudado, como "não ligar antes das 18 h".

### 6. Edite o resumo
Clique no lápis **Edit summary**, reescreva (até 1.500 caracteres) e clique em **Save** (ou **Cancel**). A IA recebe o seu texto na próxima rodada e mantém o que continua verdadeiro, mas o resumo não fica travado: a IA pode reescrevê-lo depois. Para algo que precisa ficar, use um fato fixado.

### 7. O que a IA pode e não pode mudar

| Item | Escrito por | A IA pode mudar ou apagar? |
|---|---|---|
| Fato sem marca, não fixado | A IA | Sim: muda quando o cliente corrige e apaga quando deixa de ser verdade ou o resumo já o cobre |
| Fato marcado **team** | Uma pessoa (escrito ou editado) | Não |
| Fato fixado | A IA ou uma pessoa | Não: a IA o lê primeiro e nunca o muda |
| Summary | A IA | Atualiza a cada rodada; se você o editar, ela mantém o seu texto mas pode reescrevê-lo depois |

### 8. Como a IA usa a memória
Antes de cada resposta, a IA recebe uma seção "CUSTOMER MEMORY" com o resumo e os fatos: primeiro os fixados, depois os mais novos, até 1.500 caracteres no total (um resumo longo deixa menos espaço para os fatos, então mantenha-o curto). A IA usa para não perguntar de novo o que o cliente já disse e para continuar de onde as coisas estão. O que o cliente escreve agora sempre vale mais que a memória, e a IA nunca diz que guarda anotações sobre o cliente. Se a memória não puder ser lida, a IA simplesmente responde sem ela.

## O que a IA escreve e o que nunca escreve
- **Escreve** o que o cliente disse, decidiu ou prometeu: quem é, o negócio, orçamento, decisões, objeções, preferências, o que comprou, contexto pessoal que compartilhou e compromissos em aberto com data ou responsável (retirados quando cumpridos).
- **Não escreve** o que a empresa ou a IA fez ou disse (que um preço, um orçamento ou um link foi enviado, quem atendeu, o que a equipe respondeu), cumprimentos e conversa fiada, os preços e regras da própria empresa, suposições, estados do momento ("está online agora"), números de cartão, senhas ou documentos.
- **Cada informação vai em um lugar só:** o que é só o pedido ou a situação atual vai no resumo; o que continua verdadeiro vai em um fato. Um fato que o resumo já cobre é retirado, e um fato que já está na memória com outras palavras não é acrescentado de novo.

## Contatos juntados e apagados
- **Merge** (Contacts → abra um contato → aba **Merge**): os fatos dos dois contatos ficam com o contato que permanece, os dois resumos são postos um depois do outro e a IA relê as conversas para completar o que faltar.
- **Apagar um contato** apaga a memória dele.

## Quando algo falha ou parece errado

| O que você vê | O que fazer |
|---|---|
| "Nothing remembered yet ..." | Normal para um cliente novo. Espere a conversa ficar 30 minutos parada. Se nunca preencher: a caixa não tem uma IA respondendo, a conversa tem mais de 7 dias, a conta está no teto mensal de IA, ou o workflow "CortexGen Memória" está parado (pergunte ao administrador da instalação) |
| A memória não atualiza | As mesmas conferências; lembre também que só mensagens novas do cliente iniciam uma nova rodada |
| "Could not save the AI memory. Try again." | Tente de novo; um fato pode ter até 300 caracteres e o resumo até 1.500 |
| A IA pergunta de novo o que o cliente já disse | Acrescente o fato você mesmo e fixe |
| Um fato errado | Edite (ele passa a **team**, e a IA não mexe mais) ou apague |
| Um fato que é só uma ação da empresa, ou que repete o resumo | Apague; a IA deve evitar isso desde o último ajuste, e avise o administrador da instalação se continuar acontecendo |
| A memória parece longa demais | Mantenha o resumo curto: resumo e fatos juntos chegam à IA só até 1.500 caracteres, e o que passa fica de fora |

## Não incluído
- Sem memória para clientes que nunca falaram por uma caixa com um bot de IA.
- Sem visão de todas as memórias de uma vez nem busca por memória: é um cliente por vez.
- Sem histórico das mudanças (quem mudou qual fato); só o estado atual.
- Sem confirmação antes de apagar um fato, e sem como trazê-lo de volta.
- A IA não guarda documentos, senhas nem números de cartão.
