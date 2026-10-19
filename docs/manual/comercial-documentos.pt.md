# Orçamentos e faturas: criar, enviar e acompanhar

Crie orçamentos, faturas e recibos com a sua marca em espanhol, português ou inglês, envie por chat ou e-mail, deixe o cliente aceitar um orçamento ou pagar uma fatura num link, e guarde todos os PDFs. Fica no menu, em **CRM → Quotes & invoices**.

*Também em: [English](comercial-documentos.en.md) · [Español](comercial-documentos.es.md)*

*Módulo Commerce: [Catálogo e empresa](comercial-catalogo.pt.md) · [Cobrança online e assinaturas](comercial-cobranca.pt.md) · [Página pública do catálogo](comercial-vitrine.pt.md)*

## Antes de começar

1. **Commerce ligado** na sua conta (um administrador da instalação faz isso no Super Admin, marcando **Commerce** nas funções da conta).
2. **Dados da empresa preenchidos**: nome, logo, documento fiscal, condições padrão e prefixos de numeração. Todo documento os copia. Veja [Catálogo e empresa](comercial-catalogo.pt.md).
3. **Os itens do catálogo** são opcionais: uma linha também pode ser digitada livremente.
4. **Para enviar por chat**, o cliente precisa ser um contato com uma conversa num canal que entregue mensagens ao cliente (WhatsApp, por exemplo). Uma caixa que só guarda transcrições de ligações não entrega nada e não é oferecida. **Para enviar por e-mail**, você precisa do e-mail do cliente, e a instalação precisa conseguir enviar e-mails.
5. **Para o cliente pagar online**, conecte antes um provedor. Veja [Cobrança online e assinaturas](comercial-cobranca.pt.md).
6. **Quem pode fazer o quê.** Toda a equipe cria, edita, gera PDF, envia, marca orçamentos como aceitos ou recusados, cria faturas, reabre e arquiva. Só os administradores podem usar **Void**, **Delete draft**, registrar ou remover pagamentos e emitir um recibo à mão.

## Passo a passo

### 1. Crie o documento
**CRM → Quotes & invoices**. As abas **Quotes**, **Invoices** e **Receipts** trocam a lista. Clique em **New quote** ou **New invoice**. Um **Draft** (rascunho) é criado na hora, com o seu número (por exemplo `COT-2026-0001`), a data de hoje, a moeda padrão, as condições e o rodapé padrão da empresa, e todas as formas de pagamento ativas marcadas.

Os recibos não são criados aqui: nascem dos pagamentos (veja o passo 11). Para fazer uma fatura a partir de um orçamento, veja o passo 9.

### 2. Preencha o cliente
No bloco **Customer**, digite pelo menos 2 letras em "Search a contact to fill in" e escolha o contato: nome, e-mail, telefone e os dados fiscais lembrados de documentos anteriores são preenchidos. Ou digite tudo à mão: Name, Tax ID type, Tax ID, Email, Phone e Address.
- O documento fiscal e o endereço que você digita ficam lembrados no contato para o próximo documento.
- Escolha um contato se quiser enviar por chat. Um documento sem contato só pode ser enviado por e-mail.

### 3. Escolha os ajustes do documento
No bloco **Document**:

| Campo | O que faz |
|---|---|
| Document language | Espanhol, português ou inglês. O PDF, a página do cliente, o e-mail e o texto do chat usam esse idioma |
| Currency | USD, BRL ou EUR. Nada é convertido: os preços das linhas são números nessa moeda |
| Prices and taxes | **Prices without tax (tax is added)**, **Prices include tax** ou **Tax exempt**. Veja o exemplo abaixo |
| Issue date | Começa como hoje |
| Valid until (orçamento) / Due date (fatura) | Opcional. Passada essa data, um orçamento enviado mostra **Expired** e uma fatura não paga mostra **Overdue** |
| Payment methods shown on this document | As formas ativas da empresa, todas marcadas. As marcadas "(Pay button)" cobram online |

Exemplo com uma linha de 2 × 100.00, desconto de 10% e imposto de 7%:
- **Prices without tax:** Subtotal 200.00, Discount 20.00, Tax 12.60, **Total 192.60**.
- **Prices include tax:** os 180.00 depois do desconto já contêm o imposto. Total 180.00, "Tax included" 11.78.
- **Tax exempt:** a coluna de imposto some e o total é 180.00.

### 4. Adicione os itens
No bloco **Items**, escolha em **Add from catalog…** ou clique em **Add line** para uma linha livre. Cada linha tem o nome e uma descrição, **Qty**, **Unit**, **Unit price**, **Disc. %** e **Tax %** (não aparece quando o documento é isento de imposto), e o total da linha. O xis remove uma linha.
- Uma linha com o preço unitário vazio aparece para o cliente como "Price on request" e conta como zero no total.
- Os totais da tela (**Subtotal**, **Discount**, **Tax**, **Total**) são uma prévia enquanto você digita. Depois de **Save**, valem os números calculados pelo servidor.

### 5. Observações, condições e rodapé
No fim: **Notes**, **Default terms** (é assim que o campo se chama no editor) e **Footer**. Eles são impressos no PDF e na página do cliente. As condições e o rodapé começam com os padrões da empresa e podem ser mudados em cada documento.

### 6. Salve, gere o PDF e guarde o arquivo
- **Save** guarda as suas alterações ("Saved.").
- **Generate PDF** salva primeiro, cria um PDF novo e o abre em outra aba.
- **PDF archive** lista todos os PDFs gerados do documento, com a data.
- **Send** sempre anexa o PDF **mais recente**. Se você mudou o documento depois de gerar um PDF, clique em **Generate PDF** de novo antes de enviar. (Se o documento ainda não tem PDF, um é feito ao enviar.)
- O PDF aceita letras da Europa ocidental. Outros caracteres, como cirílico ou emojis, são impressos como "?".

### 7. Envie ao cliente
Clique em **Send**. A janela "Send COT-2026-0001" tem duas abas.
- **Chat:** escolha a conversa (a lista mostra a caixa, o número, o estado e a última mensagem) e, se quiser, escreva uma **Message**. O cliente recebe **duas mensagens**: primeiro o PDF sozinho, depois um texto com o link do documento. Sem mensagem sua, o texto é o padrão no idioma do documento, com o primeiro nome do cliente, o total (o saldo nas faturas) e o link.
- **Email:** **To** (começa com o e-mail do cliente), **Subject** e **Message**, ambos com um padrão no idioma do documento. O cliente recebe um e-mail com o seu logo, o número, o total e o prazo, um botão para a página do documento ("Pay online" em faturas com pagamento online) e o PDF anexo. As respostas vão para o e-mail da empresa.

Ao enviar, um **Draft** vira **Sent** e o documento lembra a conversa e o e-mail usados. Os recibos seguem os mesmos canais. Você pode enviar de novo a qualquer momento.

### 8. O que o cliente vê
O botão **Customer link** (aparece quando o documento deixa de ser rascunho) abre a página que o cliente recebe. Um rascunho não tem página. A página mostra a empresa, o documento, as linhas, os totais, as formas de pagamento sem cobrança online com as suas instruções, as observações, as condições e o rodapé, no idioma do documento.

| Botão | English | Español | Português |
|---|---|---|---|
| Aceitar o orçamento | Accept quote | Aceptar cotización | Aceitar orçamento |
| Recusar o orçamento | Decline | Rechazar | Recusar |
| Baixar o PDF | Download PDF | Descargar PDF | Baixar PDF |
| Pagar online (faturas) | Pay with … | Pagar con … | Pagar com … |

Os botões de aceitar e recusar só existem num orçamento **Sent** que não venceu. O botão de pagar só existe numa fatura com saldo (veja [Cobrança online e assinaturas](comercial-cobranca.pt.md)).

### 9. Quando o cliente responde
- **Accept quote / Decline** no link passam o orçamento para **Accepted** ou **Declined**, e o cliente vê uma confirmação na página.
- Se o orçamento foi enviado **por uma conversa**, aparece nela uma nota interna (privada) mencionando o responsável pelo negócio (ou o primeiro administrador quando não há negócio), com o total e um link para o documento. A menção chega a essa pessoa como notificação no sino. Numa aceitação, a nota diz para criar a fatura. Um orçamento enviado só por e-mail não gera nota.
- A sua equipe pode responder no lugar do cliente com **Mark accepted** e **Mark declined**. Eles não criam nota nem fatura automática.
- Um orçamento depois da data **Valid until** não pode mais ser respondido no link, mas **Mark accepted** continua funcionando.

### 10. Crie a fatura
- **Create invoice**, num orçamento que não esteja Declined nem Void, cria uma fatura nova em **Draft** com o mesmo cliente, linhas, textos e formas de pagamento, e a abre. O orçamento vira **Accepted** se ainda não era. A data de vencimento não é copiada: defina na fatura. Clique no botão **uma vez só**: cada clique cria outra fatura.
- **Fatura automática.** Em **Company & payments → Automation**, marque "When the customer accepts a quote on its link, create the invoice and send it through the same channels as the quote (chat and email)". A partir daí, quando um cliente clica em **Accept quote**, a fatura é criada e enviada pela mesma conversa e pelo último e-mail usado no orçamento, e a nota interna avisa a sua equipe que a fatura foi criada. Ela não age com **Mark accepted**, não se repete se o orçamento já tem fatura e vem desligada.

### 11. Faturas, pagamentos e recibos
- Uma fatura vira **Partially paid** quando os pagamentos recebidos são menores que o total, e **Paid** quando o alcançam. O bloco **Payments received** aparece quando a fatura deixa de ser rascunho.
- Os **pagamentos online** se registram sozinhos, com a marca "Online" e o número do recibo. Veja [Cobrança online e assinaturas](comercial-cobranca.pt.md).
- **Record payment** (administradores) registra um pagamento recebido fora do sistema. Campos: **Amount** (começa com o saldo), **Paid on**, **Payment methods**, **Note**, e a caixa **Issue and send the receipt**, marcada por padrão.
- Quando uma fatura fica **Paid**, o negócio aberto do contato no Pipeline vai para Won, com o valor da fatura.
- O ícone de lixeira remove um pagamento registrado à mão (administradores). A fatura volta a Sent ou a Partially paid e o recibo desse pagamento vira **Void**. Pagamentos online não podem ser removidos aqui: estorne no painel do próprio provedor, porque o sistema não registra estornos.
- **O recibo** é um documento próprio (`REC-2026-0001`) com o valor recebido, a forma, a data, o total da fatura, o pago até agora e o saldo. Ele é enviado pela conversa da fatura e pelo último e-mail usado na fatura. Se a fatura nunca foi enviada por chat nem por e-mail, o recibo é criado mas não enviado: abra-o na aba **Receipts** e clique em **Send**. Ao lado de um pagamento sem recibo, os administradores veem **Issue receipt**.
- Um recibo não pode mudar valor, forma, cliente nem datas. Você pode mudar o idioma, as observações, as condições e o rodapé, e gerar o PDF de novo.

### 12. Arquivar, reabrir, anular e excluir
- **Archive** tira o documento da lista principal; o botão **Archived** mostra os arquivados, e **Unarchive** o traz de volta.
- **Reopen for editing** devolve a **Draft** um documento **Accepted**, **Declined** ou **Void**. Não está disponível quando a fatura já tem pagamentos. Os PDFs gerados continuam no arquivo.
- **Void** (administradores) anula um documento que não tem pagamentos.
- **Delete draft** (administradores) exclui um rascunho de vez; clique de novo onde diz "Click again to delete". Recibos não podem ser excluídos.
- Um documento **Sent** ainda pode ser editado, e a página do cliente mostra a mudança na hora. O PDF já enviado não muda. Um documento **Accepted**, **Declined**, **Partially paid**, **Paid** ou **Void** não pode ser editado sem ser reaberto.

### 13. Rascunhos preparados pela IA
Se o assistente de IA da conta vende a partir do catálogo e um cliente pede um orçamento, a IA cria um orçamento em **Draft** com os preços do catálogo, ligado à conversa, e deixa uma nota interna mencionando o responsável pelo negócio (ou o primeiro administrador).
- O orçamento mostra a marca **Prepared by AI** na lista e no editor, e um número vermelho aparece ao lado de **Quotes & invoices** no menu, contando esses rascunhos (atualiza a cada minuto).
- Abra-o: o aviso diz "The AI prepared this quote from conversation #… with the catalog prices. Review the items, quantities and customer, then send it." **Open the conversation** leva você ao chat.
- Revise, mude o que precisar e clique em **Send**. O número diminui.
- Se o cliente mudar o pedido antes de você enviar, a IA atualiza o mesmo rascunho e deixa uma nota nova.

## Situações e o que as move

| Documento | Situações |
|---|---|
| Orçamento | **Draft**, **Sent**, **Accepted**, **Declined**, **Void**. **Expired** aparece quando um orçamento enviado passou da data "Valid until" |
| Fatura | **Draft**, **Sent**, **Partially paid**, **Paid**, **Void**. **Overdue** aparece quando uma fatura enviada ou parcialmente paga passou da data de vencimento; ela ainda pode ser paga |
| Recibo | **Draft** (criado, ainda não enviado), **Sent**, **Void** |

| Ação | De | Para | Quem |
|---|---|---|---|
| Send | Draft | Sent | Equipe |
| Accept quote / Decline (link do cliente) | Orçamento Sent | Accepted / Declined | Cliente |
| Mark accepted / Mark declined | Orçamento Draft ou Sent | Accepted / Declined | Equipe |
| Create invoice | Orçamento Draft, Sent ou Accepted | Orçamento Accepted, fatura nova em Draft | Equipe |
| Pagamento recebido | Fatura Sent ou Partially paid | Partially paid / Paid | Cliente online, ou administradores à mão |
| Remove payment | Fatura Partially paid ou Paid | Sent / Partially paid | Administradores |
| Reopen for editing | Accepted, Declined ou Void | Draft | Equipe |
| Void | Qualquer documento sem pagamentos, exceto recibos | Void | Administradores |

## Quando algo falha ou não aparece

| O que você vê | O que fazer |
|---|---|
| "COT-2026-0001 is accepted and can no longer be edited" | O documento está fechado. Use antes **Reopen for editing** |
| "COT-2026-0001 is declined: action not allowed" (ou outra situação) | A ação não se aplica a essa situação, por exemplo anular um documento que tem pagamentos, reabrir uma fatura paga ou criar uma fatura a partir de um orçamento recusado |
| "Inbox name does not deliver messages to the customer" | Essa conversa não chega ao cliente. Escolha outra conversa ou envie por e-mail |
| "This customer has no conversation yet. Pick a contact on the document or send by email." | O documento não tem contato, ou o contato não tem uma conversa que entregue. Escolha o contato no bloco **Customer** ou use a aba **Email** |
| O e-mail diz "Sent." mas o cliente não recebe | O sistema não mostra erros de entrega de e-mail. Peça ao cliente para olhar a pasta de spam e peça ao administrador da instalação para conferir a configuração do e-mail |
| O cliente vê valores antigos no PDF | **Send** usa o último PDF. Clique em **Generate PDF** depois de editar e envie de novo |
| O cliente abre o link e não encontra nada | O documento ainda está em **Draft**. Envie-o primeiro |
| O cliente não consegue aceitar nem recusar | O orçamento não está **Sent**, ou passou da data "Valid until" |
| **Delete draft**, **Void** ou **Record payment** falham ou não aparecem | São só para administradores |
| Não apareceu nota interna depois que o cliente aceitou | O orçamento não foi enviado por uma conversa. A situação muda do mesmo jeito |
| A fatura criada pela opção automática ficou em Draft | O orçamento não tinha conversa nem e-mail para enviar. Abra a fatura e envie |

## Não incluído
- Sem notas fiscais (NF-e, fatura eletrônica da DGI): os documentos são comerciais.
- Sem assinatura eletrônica do orçamento, além de o cliente clicar em **Accept quote**.
- Sem notas de crédito, estornos nem lembretes automáticos de faturas não pagas (os únicos lembretes são os das assinaturas do Yappy).
- Os números não podem ser editados nem reiniciados à mão.
- Sem modelos prontos, além do único layout de PDF, que usa o seu logo, os dados da empresa, as observações, as condições e o rodapé.
- Recibos não podem ser criados do zero: sempre nascem de um pagamento de uma fatura.
- Um orçamento não pode ser pago online: crie antes a fatura.
