# AI evolution: a IA aprende com o que a sua equipe responde

Uma vez por dia, a IA lê as conversas que não conseguiu resolver sozinha e o que a sua equipe respondeu, e propõe mudanças concretas na base de conhecimento e nas instruções dela. Nada muda até você aplicar. Fica no menu, em **AI agent → AI evolution**.

*Também em: [English](evolucao-ia.en.md) · [Español](evolucao-ia.es.md)*

## Antes de começar

1. **AI Evolution ligado** na sua conta (um administrador da instalação faz isso no Super Admin, nos recursos da conta, chave **AI Evolution**). Sem isso o item do menu não aparece.
2. **Só os administradores** da conta veem e usam o AI evolution, porque aplicar uma proposta muda a base de conhecimento e as instruções que a IA usa com todos os clientes.
3. **Uma IA respondendo suas caixas.** Uma *persona* de IA precisa responder pelo menos uma caixa (AI agent → Personas, abas **Personas** e **Channels**). As propostas vão para a base de conhecimento e para as instruções dessa persona.
4. **Algo para aprender.** A IA só lê conversas que tenham pelo menos um destes sinais:

| Sinal | O que é | O que ensina |
|---|---|---|
| Passada para a equipe, e uma pessoa respondeu | A IA passou a conversa para a equipe (a nota privada "Handoff · ...") e, depois, uma pessoa da equipe escreveu ao cliente | A resposta que a IA não sabia |
| Resposta retida pelo Jev | A mesma nota de passagem, com o rascunho que o Jev reteve (precisa do **Check before sending** do Jev ligado) | O que a IA ia dizer errado e o que a equipe mandou no lugar |
| Caso aberto pela IA | Um caso que a IA abriu (precisa do **Cases** ligado) e que a equipe respondeu pelo assistente ou resolveu com uma nota em **What was done** | O que a IA não conseguiu resolver sozinha |

5. **Quando roda.** A rodada roda uma vez por dia, às 3h da manhã, horário do Panamá. As propostas novas aparecem depois. Só são lidas as conversas paradas há pelo menos 2 horas, com atividade nos últimos 14 dias, e só a parte que não foi lida antes: o mesmo trecho nunca é pago duas vezes.
6. **Custo.** A rodada usa o modelo normal da persona (não o leve) e conta no **AI usage** e no teto mensal de IA da conta. Uma conta que atingiu o teto é pulada.
7. **Privacidade.** E-mails e telefones são retirados do texto antes de ele ir para o modelo de IA.
8. **Números que vale conhecer.**

| O quê | Valor |
|---|---|
| Conversas lidas por conta por dia | até 20 |
| Chamadas à IA por dia | uma por persona, com todas as conversas dela juntas |
| Propostas guardadas por chamada | até 10 |
| Título / texto de uma proposta | até 120 / 2.000 caracteres |
| Evidência guardada em uma proposta | as 10 conversas mais recentes (o chip conta todas) |
| Uma proposta recusada não é proposta de novo | por 90 dias |
| Propostas listadas por aba | até 200 |
| Progress | as últimas 12 semanas |

## Passo a passo

### 1. Abra as propostas
**AI agent → AI evolution**, aba **Proposals**. Um número no item do menu mostra quantas propostas esperam revisão (atualizado a cada minuto).

- **To review / Applied / Rejected** escolhem o grupo. As para revisar vêm com mais evidência primeiro.
- **All / New knowledge / Knowledge fix / Instruction** filtram por tipo.
- Quando não há nada, a tela diz "Nothing to review. Proposals appear after the daily round, when the AI handed a conversation to the team and the team answered."

### 2. Leia uma proposta
Cada cartão mostra:

- O **tipo**, **onde** ela entraria e um chip com o número de conversas que a ensinaram ("3 conversations"). Aparece **edited** se alguém mudou o texto.
- **Why:** uma frase com o motivo.
- A **evidência**: para cada conversa, **Customer:** o que o cliente disse, **Team:** o que a sua equipe respondeu e o link **Open conversation #id**.

| Tipo | O que faz | Para onde vai |
|---|---|---|
| New knowledge | Acrescenta uma seção curta com um dado que a equipe deu (um preço, um prazo, uma política, uma área atendida) | O documento de conhecimento que a IA sugere, ou o documento **Aprendizados da IA** quando nenhum serve |
| Knowledge fix | Troca uma frase da base de conhecimento que a equipe contradisse ou completou. O cartão mostra o texto a trocar, riscado, em **Replaces this text of the knowledge base** | O documento onde esse texto está |
| Instruction | Uma frase sobre como a IA deve se comportar (por exemplo, não prometer data de entrega). Nunca é um dado nem um preço | As instruções da persona |

A IA propõe só o que a sua equipe disse ou fez, nunca um preço, data ou política inventados. Se cinco clientes perguntaram a mesma coisa, você vê uma proposta com cinco conversas de evidência, não cinco propostas.

### 3. Edite e aplique
Antes de aplicar você pode mudar o texto:

- **Title** (não aparece em Instruction).
- **Text for the knowledge base** (New knowledge e Knowledge fix) ou **Instruction for the AI** (até 2.000 caracteres).

Clique em **Apply**. A mensagem "Applied" confirma, e a proposta vai para **Applied**, com quem aplicou e a data. A IA usa a mudança a partir da próxima mensagem; não precisa de nenhum deploy. O que acontece em cada tipo:

- **New knowledge:** uma seção `### Título` seguida do texto é acrescentada no fim do documento. Em **Aprendizados da IA** (um documento criado pelo sistema, com esse nome em qualquer idioma, ligado à persona na primeira vez) você encontra essas seções em AI agent → Personas → **Knowledge base**.
- **Knowledge fix:** o texto mostrado riscado é trocado pelo texto novo.
- **Instruction:** uma linha `- instrução` é acrescentada no fim das instruções da persona, sob um título `## Aprendizados` (criado na primeira vez).

### 4. Recuse
Clique em **Reject**, escreva o porquê no campo "Why not? The AI will not propose it again." (opcional, mas útil) e clique em **Reject** de novo. **Cancel** desiste. A proposta vai para **Rejected** com o seu motivo, e a IA é instruída a não propô-la de novo por 90 dias.

### 5. Desfaça
Em **Applied**, **Undo** devolve a base de conhecimento ou as instruções ao que eram antes, e a proposta volta para **To review** ("Undone: back to review"). Só funciona se ninguém editou esse texto depois de a proposta ser aplicada; senão ele recusa, para nunca apagar a edição de outra pessoa.

### 6. Acompanhe o progresso
Aba **Progress**: as últimas 12 semanas, a mais recente primeiro, das conversas nas caixas com a IA.

| Coluna | O que conta |
|---|---|
| Week of | A segunda-feira da semana |
| Conversations | Conversas em que o cliente escreveu |
| Handed to the team | Percentual dessas que foram passadas para a equipe, com uma barra |
| Replies held by Jev | Respostas que o Jev reteve antes de enviar |
| Cases opened by the AI | Casos que a IA abriu |
| Proposals applied | Propostas que você aplicou naquela semana (destacado quando maior que zero) |

Mostra a tendência ao lado das mudanças que você aplicou; não prova que uma mudança causou uma melhora.

## Quando algo falha ou para

| O que você vê | O que fazer |
|---|---|
| "Nothing to review ..." por dias | Confira: **AI Evolution** ligado; uma persona respondendo uma caixa; conversas passadas para a equipe e respondidas por uma pessoa (e paradas há 2 horas); a conta não está no teto mensal de IA; a rodada diária está rodando (pergunte ao administrador da instalação) |
| "the text to replace is no longer in the knowledge base" | Alguém editou a base de conhecimento. Mude à mão em AI agent → Personas → **Knowledge base** e depois **Reject** a proposta |
| "the knowledge document no longer exists" / "the persona no longer exists" | O documento ou a persona foram apagados; **Reject** a proposta |
| "the text changed since it was applied; undo it by hand" | O texto foi editado depois de aplicado; conserte à mão em Personas |
| "only pending suggestions can be applied" | Outra pessoa já decidiu; recarregue a página |
| "Could not save. Try again." | Tente de novo; confira se o título e o texto estão preenchidos e dentro dos limites |
| Uma proposta diz "in "Aprendizados da IA"" | É o documento compartilhado do conhecimento novo; o nome é esse porque o sistema o cria |

## Boas práticas
- Leia a evidência antes de aplicar: uma conversa estranha não é uma política. Prefira propostas com várias conversas.
- Edite o texto para o seu jeito e tire tudo o que for específico de um só cliente.
- Recuse com um motivo curto; ele ensina à IA o que você não quer.
- Depois de aplicar, olhe o **Progress** nas semanas seguintes.

## Não incluído
- Não aplica nada sozinha: toda mudança precisa do seu **Apply**.
- Não aprende com as edições que a sua equipe faz nas respostas da IA, só com o que a equipe responde quando a IA passa a conversa, com as respostas retidas e com os casos.
- Uma proposta recusada não pode ser reaberta (só as aplicadas podem ser desfeitas).
- Não há filtro por persona na tela.
- Não julga se uma mudança aplicada melhorou as coisas; o **Progress** mostra a tendência.
