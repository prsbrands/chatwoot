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

## [1.16.2] — 2026-10-06 · base Chatwoot 4.18.0

- A página da fatura agora cita o aviso do app Yappy com o texto que o cliente realmente vê: «¡Te pidieron un Yappy!» (antes: «Te solicitan un Yappy»).

## [1.16.1] — 2026-10-06 · base Chatwoot 4.18.0

- **A página da fatura espera o pagamento sem recarregar.** Antes, ela se recarregava a cada 5 segundos enquanto o cliente aprovava no app do Yappy, e parecia estar em loop. Agora mostra "Te enviamos una solicitud de pago a tu app Yappy (Banco General)…" com um indicador e consulta a situação em segundo plano. Ela só se atualiza quando o pagamento é confirmado, recusado ou vence. Enquanto espera, o formulário "Pagar" fica escondido, para evitar uma segunda solicitação. Depois de 10 minutos sem resposta, aparece um aviso com o link para voltar à fatura.
- Pagamento recusado no app ou solicitação vencida agora aparece na página, e o formulário volta para tentar de novo.
- Uma tentativa que o provedor recusa logo de início (por exemplo, celular inválido) não fica mais pendente no sistema.
- Em Company & payments, um provedor conectado sem nenhuma forma de pagamento ligada agora mostra um aviso. Sem essa ligação, a fatura não mostra o botão "Pagar".

## [1.16.0] — 2026-10-06 · base Chatwoot 4.18.0

- **Fatura paga pelo Yappy (Panamá, USD).** Em Company & payments, o cartão **Yappy** conecta o Botón de Pago V2 com o ID do comércio, a chave secreta (cifrada) e, se preciso, o domínio cadastrado no Yappy Comercial; sem domínio, vale o desta instalação. Ao conectar, o comércio é validado no Yappy.
- **Como o cliente paga:** na fatura em USD, ele digita o celular Yappy e clica em "Pagar con Yappy". O pagamento pode ser da fatura inteira ou de uma parte. Ele aprova no app, e a página espera a confirmação, atualizando sozinha.
- **Confirmação:** só o aviso do Yappy confirma, e o hash dele é conferido sempre; o valor vale o da ordem criada aqui. Pagamento recusado ou cancelado no app não mexe no saldo. Como o Yappy não tem consulta de situação, a conciliação só expira a tentativa depois de 24 h.
- O recibo, a nota interna e o negócio ganho funcionam igual ao Stripe e ao Mercado Pago.

## [1.15.0] — 2026-10-05 · base Chatwoot 4.18.0

- **Fatura paga pelo Mercado Pago Brasil (Pix, cartão, boleto e saldo MP).** Em Company & payments, o cartão **Mercado Pago** conecta a conta com o Access token, que fica cifrado. Só contas do Brasil, em BRL, são aceitas. A forma de pagamento ligada a ele vira o botão "Pagar com…" das faturas em BRL. O cliente vai para o Checkout Pro do Mercado Pago, paga a fatura inteira ou uma parte, e volta.
- **Confirmação do pagamento:** o aviso do Mercado Pago aponta para o pagamento, e o sistema lê esse pagamento na API com o token da conta. Um Pix ainda não pago fica pendente; aviso repetido não paga duas vezes. Se você cadastrar a chave secreta dos webhooks (é opcional), a assinatura também é conferida. A volta do cliente e a conciliação a cada 5 min também encontram o pagamento.
- O recibo, a nota interna e o negócio ganho funcionam igual ao Stripe.
- **Corrigido:** documento em **português** não gerava PDF nem e-mail ("pt-BR is not a valid locale"). A formatação de dinheiro não depende mais do idioma do Chatwoot.

## [1.14.1] — 2026-10-05 · base Chatwoot 4.18.0

- **Cada orçamento e fatura escolhe as formas de pagamento que mostra.** No editor, em "Payment methods shown on this document", as formas ativas aparecem marcadas e você desmarca as que não valem. A página do cliente, o PDF, o e-mail e os botões "Pagar" seguem só a escolha. Antes saíam todas as formas ativas da conta, como o Yappy antigo. Os documentos já existentes ficaram com as formas ativas de hoje; documentos ainda editáveis podem ser ajustados.
- A página não aceita pagamento por uma forma online que não foi escolhida no documento.
- **Corrigido:** um clique duplo em Save criava a forma de pagamento duas vezes, e o resultado eram dois botões "Pagar" iguais. Agora o diálogo trava enquanto salva.

## [1.14.0] — 2026-10-05 · base Chatwoot 4.18.0

- **Fatura paga online pelo Stripe.** Em Company & payments, a nova seção **Online payments** conecta a conta Stripe da empresa (modo teste ou produção). A chave fica cifrada, e o webhook de pagamento é criado sozinho. A forma de pagamento ligada ao Stripe vira o botão **"Pagar con…"** na página da fatura e no e-mail ("Pagar en línea").
- **O cliente paga a fatura inteira ou uma parte.** O valor vem preenchido com o saldo e pode ser trocado por um menor (mínimo de 1). A fatura passa a parcial ou paga sozinha, e o negócio vira ganho quando ela é quitada. Só o aviso assinado do Stripe confirma o pagamento; um aviso repetido não paga duas vezes. Se o aviso atrasar, a página confirma na volta do cliente e uma conciliação a cada 5 min recupera o resto.
- **Recibo como documento** (`REC-2026-0001`, prefixo editável). Tem PDF, página pública, envio pela conversa e por e-mail, arquivo e os 3 idiomas, como cotações e faturas, e uma aba própria na lista.
  - **Pagamento online:** o recibo é emitido e enviado sozinho, pelos mesmos canais da fatura, e a equipe recebe uma nota interna na conversa.
  - **Pagamento manual:** o diálogo tem "Issue and send the receipt", já marcado.
  - **Conteúdo:** o recibo mostra o valor recebido, quanto já foi pago e o saldo restante.
  - **Alterações:** apagar um pagamento manual anula o recibo dele. Pagamento online não se apaga pela tela; o estorno é feito no Stripe.

## [1.13.3] — 2026-10-05 · base Chatwoot 4.18.0

- **Política de privacidade e Termos de serviço públicos** em `/privacy` e `/terms` (espanhol, inglês e português), em nome da PRS Global Business LLC (Santa Fe, NM, EUA). São as páginas exigidas pelo Google para publicar o app OAuth do Google Agenda: dizem quais permissões são pedidas, para quê, o compromisso de Uso limitado e como revogar.

## [1.13.2] — 2026-10-05 · base Chatwoot 4.18.0

- **Anexos chegam no WhatsApp por QR.** Nenhum anexo enviado do Chatwoot (PDF, foto do atendente) chegava: o adaptador do OpenWA, por segurança, não segue o endereço que redireciona para o arquivo, e descartava a mensagem inteira. Agora vai o endereço direto do arquivo.
- **Enviar documento pela conversa**: a lista mostra a caixa, a última mensagem e quando foi, da mais recente para a mais antiga; caixas que não entregam ao cliente (a de voz) ficam fora, e o servidor recusa o envio para elas.
- **E-mail do orçamento ou fatura com a marca da empresa**: logo, a mensagem, quadro com número, total e prazo, botão para o link público, assinatura e rodapé, no idioma do documento, com o PDF anexo.
- Desligado nas 3 contas (Super Admin) o "Email Continuity on API Channel" do Chatwoot, que mandava ao cliente, por e-mail, cópias da conversa do WhatsApp por QR.

## [1.13.1] — 2026-10-05 · base Chatwoot 4.18.0

- **Arquivar documentos**: o orçamento ou a fatura só sai da lista quando você pede (perdido, vencido...) e vai para **Arquivados**, de onde pode voltar.
- **Reabrir para edição**: orçamento aceito ou recusado, ou documento anulado, volta a rascunho para ser editado; os PDFs antigos ficam no arquivo. Fatura com pagamento não reabre. Excluir continua só para rascunhos.
- Corrigido: depois de "Create invoice" a tela continuava mostrando o orçamento, e o "Generate PDF" dava erro.

## [1.13.0] — 2026-10-05 · base Chatwoot 4.18.0

- **Orçamentos e faturas** (menu CRM → Quotes & invoices). Cliente puxado de um contato (os dados fiscais ficam lembrados no contato), idioma do documento (espanhol, português ou inglês), moeda, data e validade ou vencimento, linhas do catálogo ou livres com quantidade, unidade, desconto e alíquota de imposto por linha. Três modos de imposto: preço sem imposto (soma por fora), preço com imposto incluso ou isento. Numeração COT-2026-0001 e FAT-2026-0001, com o prefixo editável em Company & payments.
- **PDF com a sua marca**: logo, dados da empresa e do cliente, itens, totais, formas de pagamento com as instruções, condições e rodapé. Cada PDF gerado fica arquivado no documento, para consultar, reimprimir e reenviar.
- **Envio** pela conversa (o PDF vai anexo, com o link) ou por e-mail (PDF anexo). Em branco, a mensagem sai no idioma do documento.
- **Link público** para o cliente ver o documento e baixar o PDF; no orçamento, os botões Aceitar e Recusar.
- **Orçamento → fatura** com um clique. Pagamentos recebidos (inclusive parciais) com forma de pagamento; fatura paga por inteiro marca o negócio do cliente como ganho, com o valor da fatura.
- Busca do catálogo e dos documentos sem diferenciar acento ("maria" acha "María").

## [1.12.1] — 2026-10-05 · base Chatwoot 4.18.0

- **A tela Company & payments abre.** Na 1.12.0 ela ficava em branco: o exemplo de e-mail num dos campos tinha um "@", que o sistema de traduções da tela lê como comando.

## [1.12.0] — 2026-10-05 · base Chatwoot 4.18.0

- **Catálogo** (menu CRM → Catalog, flag `commerce` por conta): produtos e serviços com categoria, código, descrição, unidade (un, hora, m², projeto…), até 10 imagens e preço com moeda (USD, BRL, EUR). Sem preço, o item aparece como "sob orçamento" — para o que é medido, projetado ou feito sob medida. Busca e filtros por tipo e categoria. Todos consultam; só admin cadastra.
- **Empresa e pagamentos**: logo, nome fantasia, razão social, documento fiscal (RUC, CNPJ, EIN…), endereço, telefones, e-mail, site, moeda padrão, condições e rodapé — os dados que saem nos orçamentos e faturas da próxima fase. Formas de pagamento aceitas (dinheiro, transferência, Pix, Yappy, cartão, link…) com as instruções ao cliente.

## [1.11.0] — 2026-10-05 · base Chatwoot 4.18.0

- **Uso de IA por conta.** Tela nova (menu AI → AI usage): quanto a IA gastou no período, por dia, por tipo (respostas, resumos da passagem, follow-ups e decisões do Jev) e por modelo, e o custo médio por conversa. O custo vem do que o OpenRouter cobra em cada chamada.
- **Teto mensal de gasto, definido no Super Admin.** Na página da conta, o Super Admin vê o gasto do mês e define o teto em dólares (em branco = sem teto). Com o mês no teto, o bot não chama a IA: a mensagem nova vai para a equipe com uma nota, e o follow-up da conta para até o mês virar.

## [1.10.0] — 2026-10-03 · base Chatwoot 4.18.0

- **A IA desmarca e muda de horário pelo WhatsApp.** "Desmarca mi reunión del martes" cancela o compromisso na Agenda e no Google, com o motivo do cliente, e quem atende é avisado por menção; a IA confirma e pergunta se o cliente quer outro horário. "Muévela al miércoles a las 10" marca o novo horário e só então cancela o antigo. Quando não fica claro qual compromisso ou o que fazer, a IA pergunta, sem pedir dados que não servem (ano, e-mail).
- **O bot não fala depois que uma pessoa assumiu.** Se a conversa foi atribuída a alguém enquanto a IA escrevia (uma automação, ou alguém pela tela), a resposta não sai.

## [1.9.3] — 2026-10-03 · base Chatwoot 4.18.0

- **Link do Meet logo depois da marcação.** Quando a IA marca um tipo com Google Meet, o cliente recebe o link da reunião numa mensagem logo após a confirmação, no idioma dele. Antes, o link só chegava no lembrete.

## [1.9.2] — 2026-10-03 · base Chatwoot 4.18.0

- **A IA marca o horário que o cliente pede, sem depender de lembrar.** Quando o cliente pede ou aceita um horário livre ("martes 6 a las 11am", "10"), o sistema identifica qual é e marca antes de a IA escrever; a IA só confirma. Antes, a marcação dependia de uma linha escondida que a IA às vezes esquecia, e a conversa ia para a equipe sem horário marcado. Quando não há certeza do horário, segue o caminho de antes: a IA oferece opções.

## [1.9.1] — 2026-10-02 · base Chatwoot 4.18.0

- **A IA não confirma horário sem marcar.** Quando o cliente pede um horário exato que está livre ("martes a las 9"), a IA marca na hora. Se mesmo assim ela disser ao cliente que o horário está confirmado sem ter marcado, a resposta não sai: a conversa passa para a equipe, com o rascunho e o motivo numa nota. Antes, a IA confirmava em texto e nada entrava na Agenda.

## [1.9.0] — 2026-10-02 · base Chatwoot 4.18.0

- **Aviso ao responsável** quando a IA marca: uma nota privada na conversa menciona quem atende. Isso gera a notificação do Chatwoot no sino, por e-mail e por push, conforme as preferências de cada um.
- **Google Meet automático:** o tipo ganha "Create a Google Meet link". O evento no Google de quem atende ganha uma sala do Meet, o link aparece no compromisso e o marcador **{link}** o leva para as mensagens ao cliente (o Meet, ou o local).
- **Negócio anda ao marcar:** o tipo ganha "When booked, move the deal to…". O negócio do contato vai para essa etapa, só para a frente e no mesmo funil, e o histórico registra quem moveu (a pessoa, ou a IA).
- **Presença cobrada no Radar:** os compromissos que já passaram sem desfecho aparecem num bloco próprio, com "Mark as done" e "Did not show up".
- **Mensagem de falta:** marcar "Did not show up" manda ao cliente a mensagem do tipo pelo WhatsApp por QR. Quando ele responde, a IA oferece novos horários.

## [1.8.1] — 2026-10-02 · base Chatwoot 4.18.0

- Os diálogos de tipo de agendamento, compromisso e tarefa ganharam rolagem: em telas mais baixas, o botão Save ficava fora do alcance.

## [1.8.0] — 2026-10-02 · base Chatwoot 4.18.0

- **A IA marca na conversa.** Nova atividade do Jev, **"Notice a wish to book"**, que já entra decidindo e pode ser passada para observar ou desligada.
  - Quando o cliente quer marcar, a IA recebe os horários livres do tipo marcado como **"The AI can book this type"**.
  - A IA **pergunta primeiro qual dia e período o cliente prefere** e oferece até 3 horários. Quando o cliente aceita, o sistema confere de novo se o horário continua livre e marca o compromisso com o contato, a conversa e o negócio. O compromisso vai para o Google de quem atende, e uma nota fica na conversa.
  - Se o horário for ocupado no meio do caminho, o cliente recebe as próximas opções no idioma dele.
- **Lembretes pelo WhatsApp por QR:** cada tipo pode avisar o cliente X horas antes, com o texto que você escrever usando {name}, {date}, {time} e {type}. No WhatsApp oficial, os lembretes ficam para quando houver um template aprovado.
- A revisão do Jev não segura mais a confirmação de um horário que o próprio sistema marcou.

## [1.7.0] — 2026-10-02 · base Chatwoot 4.18.0

- **Tipos de agendamento** (Agenda → engrenagem): nome, duração, folga antes e depois, antecedência mínima, até quantos dias à frente se marca, quem atende por padrão e se o compromisso nasce "aguardando confirmação". Só admin cria e altera.
- **Jornada de cada pessoa**, na mesma tela: os dias e as faixas em que ela atende, no fuso dela. Cada um ajusta a própria jornada; o admin ajusta a de qualquer um.
- **Horários livres ao marcar:** escolhido o tipo, o compromisso sugere os horários livres do dia, descontando a jornada, a antecedência, as folgas, os compromissos já marcados e o ocupado do Google. Se o Google não responder, os horários saem sem ele e com aviso.
- A linha da hora atual voltou a aparecer na grade da Agenda.

## [1.6.0] — 2026-10-02 · base Chatwoot 4.18.0

- Nova **Agenda**, no topo do menu e em **todas as contas**: compromissos com hora marcada, em grade de dia ou de semana, com "minha agenda", "equipe inteira" ou a agenda de uma pessoa. Clicar num horário vazio marca ali.
- Cada compromisso tem título, quando, duração, quem atende, quem é atendido (busca de contato), onde e notas, e pode ser confirmado, realizado, "não compareceu" ou cancelado.
- **Google Calendar por pessoa**: cada um conecta a própria conta Google na Agenda, troca de conta ou desconecta.
  - Os compromissos vão para a agenda principal do responsável no Google, e saem de lá quando são apagados ou mudam de responsável.
  - O que está ocupado no Google aparece em cinza na grade.
  - Se o Google parar de aceitar a conexão, a Agenda pede para conectar de novo.
  - O app OAuth fica em Super Admin → Settings → Google Calendar.
- No **card do negócio**, o botão "+ Appointment" marca com o contato e o negócio já preenchidos, e os próximos compromissos aparecem logo abaixo. No Radar, um compromisso marcado também conta como próximo passo.
- Tarefas: só a data atrasada fica vermelha, o link do negócio ficou do tamanho certo, e as listas perderam o marcador "•".

## [1.5.0] — 2026-10-02 · base Chatwoot 4.18.0

- **Tarefas** (Tasks, no menu em CRM): o que ficou combinado, com prazo e responsável, ligado a um negócio ou a um contato, ou avulso.
  - A lista separa Atrasadas (em vermelho), Hoje, Próximas e Sem prazo, com abas A fazer e Feitas e o filtro Minhas / De todos.
  - Dá para criar, editar, concluir, reabrir e excluir. Excluir é de quem criou ou de um admin.
- **Próximos passos no card do negócio** na conversa: as tarefas pendentes do negócio e o botão "+ Task". Sem tarefa, o card avisa que falta o próximo passo.
- **Radar: "sem próximo passo"**, um bloco com os negócios abertos que não têm nenhuma tarefa pendente, nem no negócio nem no contato. É o único número do Radar cujo alvo é zero.
- Excluir um contato agora exclui também os negócios e as tarefas dele. Antes, o negócio ficava órfão e podia quebrar o Kanban.

## [1.4.0] — 2026-10-02 · base Chatwoot 4.18.0

- **Menu por jornada**, como o do CRM. No topo fica o atendimento (Inbox, Conversations, Risk radar). Depois vêm as seções, com título:
  - **CRM**: Pipeline, Contacts, Companies, Campaigns;
  - **AI agent**: Personas, Jev;
  - **Channels**: Connections, Help Center;
  - **Analysis**: Reports;
  - **Account**: Settings.
- Personas e Jev saíram do fundo de Configurações → Integrações e ganharam item próprio no menu.
- Novas páginas **View all in CRM** e **View all in AI**, com um card por tela, separado por jornada ("o dia a dia da venda", "preparar a venda", "montar / ensinar / acompanhar o agente") e uma linha dizendo para que serve cada uma. Cada pessoa vê só os cards das telas que pode abrir.
- O ponto de alerta de Connections ficou vermelho.
- A tela de Bot Personas abre direto na aba pedida (personas, knowledge ou channels).

## [1.3.0] — 2026-10-02 · base Chatwoot 4.18.0

- Novo **Radar de risco**, no menu logo abaixo do Pipeline. Lista os negócios abertos que esfriaram, do mais urgente para o menos:
  - **Critical**: parado há 3 vezes o tempo esperado da etapa ou mais;
  - **Going cold**: passou do tempo esperado da etapa;
  - **Bot follows up**: o bot ainda vai retomar a conversa pelo follow-up.
- Cada linha mostra o funil e a etapa, há quanto tempo está parado, o score, quem cuida (uma pessoa, a IA ou ninguém) e quando a IA retoma.
- O botão **Take over** passa a conversa para quem clicou, e a IA para de responder nela.
- Conexões: o WhatsApp por QR ganha o ícone do WhatsApp e as caixas de voz um telefone; o aviso de canais com problema usa o plural certo.

## [1.2.0] — 2026-10-02 · base Chatwoot 4.18.0

- Nova tela **Conexões** (Connections), no menu lateral, só para administradores. Ela reúne todos os canais da conta, com o WhatsApp separado entre **QR** e **API oficial (Meta)**, e mostra se cada canal está conectado e quem responde nele: a persona da IA ou a equipe.
- Os botões "WhatsApp por QR" e "API oficial" levam direto para conectar um número.
- **Canal mudo** fica em vermelho, com o botão **Corrigir**, e acende um ponto no item do menu. Isso acontece quando o WhatsApp caiu, ou quando o bot está ligado sem persona (ou com credencial velha), ou com persona mas sem o bot na caixa. Foi assim que o Instagram e o Messenger ficaram sem resposta de agosto a 02/10 sem ninguém perceber.
- A tela de Bot Personas abre direto na aba Channels quando chamada pelo "Corrigir".

## [1.1.0] — 2026-10-02 · base Chatwoot 4.18.0

- O bot responde **no idioma do cliente** durante toda a conversa, mesmo quando a persona e a base de conhecimento estão escritas em outro idioma. Antes, a resposta que usava a base voltava para o espanhol.
- Nova atividade do Jev, **"Tell the customer's language"**, que já entra decidindo: o Jev diz ao bot se o cliente escreve em espanhol, português ou inglês, e um "ok" curto mantém o idioma de antes. Dá para passar a só observar ou desligar no cartão do Jev; sem o Jev, o bot continua instruído a responder no idioma do cliente.
- No WhatsApp por QR, negrito, títulos e links da resposta do bot saem no formato do WhatsApp, sem os `**` aparecendo. O WhatsApp oficial, o Instagram e o Messenger já eram convertidos pelo próprio Chatwoot.

## [1.0.2] — 2026-10-01 · base Chatwoot 4.18.0

- O seletor de etapa do card **Deal** na conversa voltou a listar as etapas (estava vazio).
- A etapa de cada funil tem no máximo um "passo do agente", garantido também no banco.
- Revisão do código do CortexGen com o rubocop e o eslint do projeto: 40 + 183 achados zerados, textos soltos levados para tradução e as setas das telas de voz trocadas por ícones. Nenhuma mudança de comportamento.

## [1.0.1] — 2026-10-01 · base Chatwoot 4.18.0

- O WhatsApp por QR não mostra mais **"Failed to send"** em mensagens que chegaram ao cliente. O Chatwoot desistia depois de 5 segundos de espera pelo adaptador, que só responde depois de entregar ao WhatsApp. O canal agora espera até 30 segundos, ajustável em Super Admin → Settings ("API inbox webhook timeout"), e os outros webhooks continuam com 5.
- As 14 mensagens da inbox 33 marcadas como falha por esse motivo foram corrigidas para "enviada".

## [1.0.0] — 2026-10-01 · base Chatwoot 4.18.0

O CortexGen Chat passa a ser um CRM completo: atendimento, bot com IA, follow-up e funil de vendas no mesmo lugar.

**Radar de risco e score (bloco 3c)**
- Cada negócio aberto tem um estado de risco, recalculado a cada 5 minutos pela última interação real com o cliente:
  - **em dia** dentro das horas esperadas da etapa;
  - **esfriando** acima delas;
  - **crítico** com o triplo.
- Notas internas e mensagens de sistema não contam como interação.
- Score de 0 a 100 por fórmula, sempre com os fatores que o compõem:
  - +12 por compromisso (próximo passo, pediu proposta, quer comprar);
  - −8 por objeção (preço, momento, concorrente ou dúvida);
  - +5 por qualificação (necessidade, orçamento, prazo, quem decide);
  - a recência entra pelo risco.
- Faixas quente, morno e frio. Sem pelo menos dois sinais, não há score.
- Os sinais vêm do Jev, na mesma leitura que avalia a etapa.
- No Kanban: score e ponto de risco em cada card, e o filtro **Only at risk**.
- No card Deal da conversa: o score com os fatores e há quanto tempo o negócio está sem interação.

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
