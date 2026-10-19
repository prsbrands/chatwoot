# Cobrança online e assinaturas

Deixe os clientes pagarem faturas online, inteiras ou em parte, e cobre planos mensais ou anuais de forma automática. O pagamento fica registrado, a fatura se atualiza e o recibo é enviado sem ninguém da sua equipe mexer em nada. Os provedores são conectados em **CRM → Catalog → Company & payments → Online payments**, e as assinaturas ficam no menu, em **CRM → Subscriptions**.

*Também em: [English](comercial-cobranca.en.md) · [Español](comercial-cobranca.es.md)*

*Módulo Commerce: [Catálogo e empresa](comercial-catalogo.pt.md) · [Orçamentos e faturas](comercial-documentos.pt.md) · [Página pública do catálogo](comercial-vitrine.pt.md)*

## Antes de começar

1. **Commerce ligado** na sua conta (um administrador da instalação faz isso no Super Admin, marcando **Commerce** nas funções da conta).
2. **Uma conta sua no provedor.** O dinheiro vai direto para a sua conta lá.

| Provedor | Conta | Moedas | O que o cliente usa | O que você cola no sistema |
|---|---|---|---|---|
| Stripe | Uma conta Stripe | USD, EUR, BRL | A página de pagamento hospedada pelo Stripe | A secret key |
| Mercado Pago | Só Mercado Pago **Brasil** | BRL | Cartão, Pix, boleto ou saldo do Mercado Pago, na página do Mercado Pago | O Access token |
| Yappy | Yappy Comercial (Botón de Pago) | USD | Aprovar o pagamento no app do Yappy | Merchant ID, Secret key e, se precisar, o domínio |

3. **Teste primeiro em modo de teste.** Todo provedor pode ser conectado como **Test mode** e depois passar para **Live** com as chaves reais (**Change key**).
4. **Uma forma de pagamento ligada ao provedor** (passo 2 abaixo) e **mantida marcada na fatura**.
5. **A moeda da fatura.** O cliente só recebe os provedores que a aceitam: uma fatura em BRL mostra Mercado Pago e Stripe, uma em USD mostra Stripe e Yappy, uma em EUR mostra Stripe.
6. **O endereço público da instalação.** Os provedores confirmam os pagamentos chamando esse endereço. Se a sua instalação não é alcançável pela internet, as confirmações nunca chegam.
7. **Quem pode fazer o quê.** Os administradores conectam e desativam provedores e cancelam assinaturas. Toda a equipe cria assinaturas e envia o link delas.

## Passo a passo

### 1. Conecte um provedor
**Company & payments → Online payments**. Cada provedor tem o seu cartão. Clique em **Connect**, escolha o **Environment** (**Test mode** ou **Live**), preencha as credenciais e clique em **Connect** de novo. Você vê "Stripe connected." (ou o nome do provedor). O cartão passa a mostrar **Active**, "Test mode · key …1a2b" (só os 4 últimos caracteres aparecem) e as moedas.

- **Stripe.** No Dashboard do Stripe, Developers, API keys, copie a **secret key** (não a publishable) ou uma chave restrita com permissão de escrita em Checkout Sessions e Webhook Endpoints. Ela precisa combinar com o ambiente: `sk_test_` ou `rk_test_` em Test mode, `sk_live_` ou `rk_live_` em Live. O webhook de pagamentos é criado sozinho; não há nada a registrar.
- **Mercado Pago.** Em Mercado Pago Developers, Your integrations, sua aplicação, Production credentials (ou as de teste), copie o **Access token** (não a Public key). Só contas do Mercado Pago Brasil são aceitas. Um token que começa com `TEST-` abre o checkout de teste.
  - **Webhook secret signature (opcional):** se você definir um segredo em Your integrations, Webhooks, cole aqui para uma conferência extra. Sem ele, cada aviso é confirmado do mesmo jeito lendo o pagamento no Mercado Pago.
  - **Para as assinaturas este passo é obrigatório.** O cartão mostra a **Webhook URL**. No Mercado Pago, Your integrations, sua aplicação, Webhooks, **modo produção**, registre esse endereço com os eventos **Payments** e **Plans and subscriptions**. Sem isso, as cobranças das assinaturas não são registradas aqui.
- **Yappy.** No Yappy Comercial, Botón de Pago, copie o **Merchant ID** e a **Secret key**, e registre o endereço da instalação (ou o domínio que você digitar em **Domain registered in Yappy (optional)**) como domínio de pagamento. Só USD.

A chave é guardada cifrada e não é mostrada de novo. **Change key** a substitui. **Disable** pausa o provedor (as formas de pagamento dele deixam de mostrar o botão de pagar) e **Enable** o traz de volta; os pagamentos já feitos continuam no histórico.

### 2. Ligue uma forma de pagamento ao provedor
**Company & payments → Payment methods**, crie ou edite uma forma e escolha o provedor em **Online charge**. A lista passa a dizer "Online with Stripe". Se o provedor está conectado mas nenhuma forma ativa o usa, o cartão dele avisa "No active payment method uses Stripe yet, so invoices show no Pay button…".

Em cada fatura, a forma precisa continuar marcada em "Payment methods shown on this document" (com a marca "(Pay button)"). O nome da forma é o texto do botão, "Pay with …", então dê um nome claro, como "Card" ou "Yappy".

### 3. O que o cliente faz
No link da fatura (ou no botão "Pay online" do e-mail) o cliente encontra **Pay online**, com **Amount to pay** já preenchido com o saldo e um botão por forma de pagamento.
- O cliente pode pagar **menos que o saldo**: pelo menos 1 unidade da moeda, ou o saldo inteiro quando ele é menor que 1.
- **Stripe e Mercado Pago:** o botão abre a página do provedor; depois de pagar, o cliente volta para a fatura. A página diz que o pagamento está sendo confirmado, se atualiza sozinha e depois agradece ao cliente e anuncia o recibo.
- **Yappy:** o cliente digita o **celular Yappy** de 8 dígitos e clica no botão. A página pede para aceitar a solicitação no app do Yappy e se atualiza sozinha quando o pagamento é confirmado. Passados 10 minutos sem confirmação, a página diz que a confirmação pode levar mais alguns minutos e oferece um link para voltar à fatura.
- Se o pagamento é recusado ou a solicitação vence, a página diz isso e o cliente pode tentar de novo. Se o pagamento nem consegue começar (valor fora do limite, celular errado, provedor que recusou), a página pede para conferir o valor e tentar de novo.

Os textos da página estão no idioma do documento.

### 4. O que acontece do seu lado
Só vale uma confirmação do provedor (o aviso que ele envia, ou a resposta quando o sistema pergunta a ele). O cliente voltar para a página não prova nada por si só. Quando ela chega:
- A fatura recebe o pagamento (com a marca "Online") e vira **Partially paid** ou **Paid**.
- O recibo `REC-…` é emitido e enviado pela conversa e pelo último e-mail usado na fatura.
- Se a fatura tem uma conversa, uma nota privada diz "Online payment received: …" com o valor, a fatura, a forma e o recibo.
- Quando a fatura fica **Paid**, o negócio aberto do contato vai para Won.
- O mesmo aviso chegando duas vezes nunca paga duas vezes.

### 5. Atrasos e a rede de segurança
- A cada 5 minutos o sistema pergunta ao provedor pelas tentativas que não tiveram resposta (passados 2 minutos) e aplica o que encontra. Uma tentativa que continua sem pagamento depois de 24 horas vence. Um cliente que volta da página do provedor também dispara uma consulta.
- O Yappy não pode ser consultado: a confirmação dele só chega como aviso, e uma tentativa sem aviso vence em 24 horas.
- Os estornos são feitos no painel do provedor. O sistema não os registra, e um pagamento que veio online não pode ser removido da fatura.

### 6. Crie uma assinatura
Uma assinatura precisa de um **plano**: um item do catálogo com **Billing** em Monthly plan ou Yearly plan (veja [Catálogo e empresa](comercial-catalogo.pt.md)).

**CRM → Subscriptions → New subscription**:
- **Customer:** busque e escolha um contato.
- **Plan:** os planos disponíveis, cada um com o seu preço.
- **Quantity:** começa em 1; a cobrança é o preço vezes a quantidade.
- **Payment method:** só as formas ativas cobradas online por Stripe, Mercado Pago ou Yappy. Stripe (USD, EUR, BRL) e Mercado Pago (BRL) cobram de forma automática. O Yappy (USD) não tem débito automático, então cada fatura de renovação é enviada 3 dias antes do vencimento com o link de pagamento.

Clique em **Create**. O preço, a moeda e o ciclo são copiados do plano, então mudanças posteriores no catálogo não afetam esta assinatura. Os detalhes se abrem sozinhos.

### 7. Envie o link ao cliente
Uma assinatura nova está **Awaiting customer** e mostra o seu link. Você pode **Copy link** e enviar como preferir, ou escolher a conversa e clicar em **Send link to this conversation**. Essa conversa passa a ser também a usada para os recibos e avisos da assinatura. O e-mail do cliente no contato também é usado, quando é válido.

O cliente abre a página "Subscription · nome do plano" com o preço por mês ou por ano e um botão **Subscribe with …**:
- **Stripe:** abre a página de pagamento do Stripe. A primeira cobrança acontece na hora.
- **Mercado Pago:** a página pede antes o **Email of your Mercado Pago account** e depois abre o Mercado Pago para autorizar a assinatura.
- **Yappy:** abre a fatura do primeiro ciclo, com vencimento hoje, e o cliente a paga com o celular Yappy, como qualquer fatura.

Quando o cliente volta, a página diz que a assinatura foi recebida e que o recibo do primeiro pagamento está a caminho.

### 8. Como cada ciclo é cobrado

| Provedor | Como cobra | O que você recebe no sistema |
|---|---|---|
| Stripe | Automaticamente, todo mês ou ano | Uma fatura paga do período e o recibo, enviado. Se uma cobrança é recusada, a assinatura vira **Past due** com uma nota privada, e o Stripe tenta de novo |
| Mercado Pago | Automaticamente, com o cartão autorizado pelo cliente. Precisa do webhook registrado no passo 1 | O mesmo: fatura paga e recibo, ou **Past due** quando recusada |
| Yappy | Assistida: 3 dias antes do fim do período a fatura do próximo ciclo é criada, com vencimento no fim do período, e o link dela sai pela conversa da assinatura e pelo e-mail do cliente. No dia do vencimento sai um lembrete por chat | Pagar essa fatura renova a assinatura. Sem pagar 5 dias depois do vencimento, a assinatura vira **Past due** com uma nota privada |

A assinatura vira **Active** quando o primeiro ciclo é pago. Uma assinatura **Past due** volta a **Active** quando uma renovação é paga.

### 9. Acompanhe e cancele
- A lista mostra o plano, o cliente, "Renews on {date}" ou "Ends on {date}", o preço por mês ou por ano e a situação: **Awaiting customer**, **Active**, **Past due** ou **Canceled**. Filtre por situação e busque por plano ou cliente.
- Clique numa assinatura para ver as **Invoices** dela: número, período, recibos, total e situação. Clique numa fatura para abri-la. Elas também estão em **Quotes & invoices**.
- **Cancel at period end** (administradores): o cliente fica com o que pagou e nenhum novo ciclo é cobrado. No Mercado Pago a cobrança para na hora e a assinatura continua **Active** aqui até o fim do período pago. **Cancel now**: encerra a assinatura na hora e anula a fatura de renovação aberta. Os dois pedem um segundo clique ("Click again to confirm").
- Uma assinatura que ainda está **Awaiting customer** sempre é cancelada na hora.
- Se um cliente pedir para cancelar por chat, um administrador faz isso aqui. A IA não cancela assinaturas.

### 10. Quando o assistente de IA vende
Se o assistente de IA da conta vende a partir do catálogo e um cliente diz qual plano quer, o assistente cria a assinatura (ou reaproveita a pendente desse plano) e envia o link na conversa. Para isso, o plano precisa estar **Available** e precisa haver uma forma de pagamento ativa cujo provedor cobre assinaturas na moeda do plano.

## Quando algo falha ou não aparece

| O que você vê | O que fazer |
|---|---|
| "The secret key does not match the sandbox environment" (ou production) | A chave e o ambiente não combinam: **Test mode** é "sandbox" e usa `sk_test_` ou `rk_test_`; **Live** é "production" e usa `sk_live_` ou `rk_live_` |
| Uma mensagem do Stripe ao conectar | A chave está errada, revogada ou sem as permissões indicadas no passo 1 |
| "This Mercado Pago account is …; only Mercado Pago Brasil (BRL) is supported" | Use as credenciais de uma conta brasileira |
| "Mercado Pago: HTTP 401 …" | O Access token está errado ou venceu. Copie-o de novo |
| "Invalid Yappy secret key" ou "Yappy: … (code)" | O Merchant ID, a Secret key ou o domínio não combinam com o que está registrado no Yappy Comercial |
| "Something went wrong. Try again." | Uma falha genérica, que também aparece quando o provedor recusa cancelar uma assinatura. Confira o painel do provedor e tente de novo |
| O cliente não vê nenhum botão de pagar | A fatura é um rascunho, está paga ou anulada, não tem saldo, a forma de pagamento está desmarcada ou inativa, o provedor está desativado, ou o provedor não aceita a moeda da fatura |
| O cliente pagou mas a fatura não mudou | Espere alguns minutos: a rede de segurança confere a cada 5. Se não mudar, olhe as entregas do webhook no painel do provedor. Uma resposta 400 significa que a assinatura não combinou (confira a Webhook secret signature no Mercado Pago, ou a Secret key no Yappy); uma resposta 404 significa que o endereço não é o que o sistema deu (a Webhook URL do cartão do Mercado Pago) |
| O cliente do Yappy vê "The payment was declined or the request expired…" | Peça ao cliente para tentar de novo, digitando o celular de 8 dígitos cadastrado no Yappy |
| "Provider is invalid" ao criar uma assinatura | O provedor dessa forma de pagamento não aceita a moeda do plano: use Stripe para USD, EUR ou BRL, Mercado Pago para BRL, Yappy para USD |
| O cliente vê "We could not start the subscription…" | A assinatura não está mais aberta (já ativa ou cancelada), o provedor a recusou, ou no Mercado Pago o e-mail é inválido. Crie um link novo se precisar |
| Uma cobrança de assinatura apareceu no Mercado Pago e não aqui | Falta o webhook com os eventos Payments e Plans and subscriptions no painel do Mercado Pago (passo 1) |
| Uma assinatura está **Past due** | A última renovação foi recusada ou não foi paga. O cliente precisa corrigir o cartão ou pagar a fatura de renovação |

## Não incluído
- Sem estornos nem chargebacks registrados no sistema; eles são tratados no painel do provedor.
- Sem repasse da taxa ao cliente: a empresa absorve a taxa do provedor.
- Só faturas são pagas online; um orçamento não pode ser pago até virar fatura.
- Uma única conexão por provedor em cada conta, e só Stripe, Mercado Pago e Yappy.
- Sem teste grátis, cupons nem troca de plano com cobrança proporcional: para trocar de plano, cancele e crie uma assinatura nova.
- Sem QR code de Pix na nossa página: o Pix é oferecido dentro da página do Mercado Pago.
- Sem lista de assinaturas no cartão do contato.
- Sem lembrete automático de faturas não pagas, exceto as renovações do Yappy.
