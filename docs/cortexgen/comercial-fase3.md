# Comercial, fase 3 — cobrança online, recibos e assinaturas (DESENHO v2)

**3a (Stripe avulso e recibo) entregue na 1.14.0**, 3b (Mercado Pago) na 1.15.0, 3c (Yappy) na 1.16.0 e **3d no Stripe na 1.17.0** e **no Mercado Pago na 1.17.1** (preapproval com cartão; o Yappy vem na 1.17.2). Diferenças da 1.17.0 para o desenho abaixo: cada ciclo envia **só o recibo** (a fatura do ciclo fica no sistema, já paga); o link vai pela conversa ou copiado (sem e-mail ainda); o card do contato ainda não mostra as assinaturas. A v2 incorpora as respostas do Paulo de 05/10:

- Contas: **Stripe EUA**, **Mercado Pago Brasil**, **Yappy Panamá**.
- O cliente **pode pagar uma parte** da fatura.
- Haverá **assinaturas mensais e anuais** de planos.
- **Recibo automático**, tratado como documento, igual à cotação: PDF, arquivo, envio, edição e arquivamento.

Os pontos marcados com **❓** ainda dependem de resposta. Onde há ❓, o texto já traz a opção que eu seguiria.

## Moedas por provedor

| Provedor | Moedas | Observação |
|---|---|---|
| Stripe (EUA) | USD; também EUR e BRL como moeda de cobrança, liquidando em USD | cartão, Apple/Google Pay |
| Mercado Pago (Brasil) | BRL | cartão, boleto, **Pix** e saldo MP, pelo Checkout Pro |
| Yappy (Panamá) | USD | aprovação no app do Yappy |

A página só oferece os provedores que aceitam a moeda da fatura. Uma fatura em BRL mostra Mercado Pago e Stripe; uma em USD mostra Stripe e Yappy.

## 1. Pagar uma fatura

**O que o cliente vê:**
1. Na página pública `/d/:token` e no e-mail da fatura aparece o botão **"Pagar"**.
2. A página mostra o **saldo em aberto** já preenchido. O cliente pode trocar por um valor menor: mínimo de 1 unidade da moeda, máximo o saldo.
3. Escolhe a forma de pagamento.
   - **Stripe e Mercado Pago:** vai para o checkout do provedor e volta para a página.
   - **Yappy:** digita o celular, aprova no app e a página espera a confirmação.
4. Quando o pagamento é confirmado:
   - a fatura passa a **parcial** ou **paga**, pelo `settle!` de hoje;
   - o **recibo** é gerado e enviado (seção 2);
   - com a fatura paga, o negócio vira **ganho**.

**Regras:**
- O valor é validado no servidor e fica entre o mínimo e o saldo.
- A volta do checkout não confirma nada. Quem confirma é o **webhook com assinatura verificada**, e há uma conciliação a cada 10 min para tentativas pendentes.
- Um aviso repetido não paga duas vezes: o id externo é único.

## 2. Recibo: um terceiro tipo de documento

O `commerce_documents.kind` ganha **`receipt`**, com numeração **`REC-2026-0001`** e o prefixo editável na empresa, como COT e FAT. O recibo reaproveita tudo da fase 2: PDF arquivado, página pública, envio pela conversa e por e-mail, arquivar e os três idiomas.

**Como nasce:**
- **Pagamento online confirmado:** nasce **sozinho e é enviado sozinho**, pelo mesmo canal do último envio da fatura (conversa e/ou e-mail).
- **Pagamento registrado à mão:** o diálogo de pagamento ganha a opção **"Gerar e enviar recibo"**, marcada por padrão.

**O que mostra:** a empresa, o cliente, a fatura de origem, o valor recebido, a forma e a data, o total da fatura, quanto já foi pago e o **saldo restante**.

**Edição:**
- Valor, forma e data vêm do pagamento e ficam travados.
- Observação, idioma e textos podem ser editados, e é possível reemitir o PDF.
- Recibo de pagamento manual: se o pagamento for apagado, o recibo é **anulado** (não some) e o saldo volta.
- Recibo de pagamento online: não se anula pela tela, porque estorno fica fora desta fase.

**Ligação no banco:** o pagamento ganha `receipt_id`. O recibo aponta para a fatura pelo `source_document_id`, que já existe.

## 3. Assinaturas mensais e anuais

**O plano é um item do catálogo** com cobrança recorrente. O `commerce_items` ganha `billing_interval`, que pode ser `one_time` (o de hoje), `month` ou `year`. O preço e a moeda continuam os do item.

**A assinatura é um registro novo,** com o cliente, o plano, a quantidade, o preço, a moeda e o ciclo, mais:
- **situação:** aguardando, ativa, em atraso, cancelada;
- **período atual**, provedor e id externo;
- **cancelar no fim do período**.

**Como começa:** o atendente cria a assinatura na tela **Assinaturas**, a partir do contato ou do negócio, e envia o link **"Assinar"** pela conversa ou por e-mail. Também dá para criar a partir de uma cotação aceita que tenha um item recorrente. O cliente abre `/s/:token`, vê o plano e o ciclo e assina pelo provedor.

**Cada ciclo, em cada provedor:**

| Provedor | Como cobra | O que entra no nosso sistema |
|---|---|---|
| **Stripe** | **Stripe Billing nativo** (Checkout no modo assinatura, com `price_data`, sem sincronizar catálogo). O Stripe cobra o cartão salvo, refaz a tentativa quando falha e cuida do 3-D Secure | Webhook `invoice.paid`: geramos a **fatura FAT** do ciclo já paga e o **recibo**, e enviamos os dois. `invoice.payment_failed` passa a assinatura para **em atraso**, com uma nota na conversa |
| **Mercado Pago** | **Assinaturas nativas do MP** (*preapproval*), com cartão. Pix e boleto não têm débito automático | Webhook `subscription_authorized_payment`: mesma fatura, recibo e envio |
| **Yappy** | Não tem débito automático. É **cobrança assistida**: 3 dias antes do vencimento, geramos a fatura do ciclo e mandamos o link de pagamento pelo WhatsApp/e-mail, com lembrete no dia | O pagamento pelo link (seção 1) gera o recibo. Sem pagamento 5 dias depois do vencimento, a assinatura fica **em atraso** |

**Cancelamento:** o atendente cancela **no fim do período** (padrão) ou na hora, e nós cancelamos no provedor pela API. O cliente pode pedir pelo WhatsApp, mas quem executa é o atendente. Neste corte, a IA não cancela assinatura.

**Fora deste corte:** troca de plano com cobrança proporcional (agora é cancelar e criar de novo), período de teste grátis (❓) e cupons.

**Tela:** **Assinaturas** no grupo CRM, com lista por situação, filtros e o detalhe com o histórico de faturas e recibos. O card do contato mostra as assinaturas ativas.

## Dados (resumo)

| Tabela | Mudança |
|---|---|
| `commerce_payment_providers` (nova) | `provider` (stripe/mercado_pago/yappy), `environment`, `credentials` e `webhook_secret` **cifrados** (`encrypts`), `webhook_token` (vai na URL do webhook), `active`. Único por conta + provedor |
| `commerce_payment_methods` | + `provider_id` |
| `commerce_checkouts` (nova) | tentativa de pagamento: documento ou assinatura, provedor, valor, moeda, situação, `external_id` (único por provedor), `checkout_url`, `payload` |
| `commerce_document_payments` | + `checkout_id` (único) e `receipt_id` |
| `commerce_documents` | `kind` + `receipt`; + `subscription_id`; + `period_start` e `period_end` (fatura de assinatura) |
| `commerce_profiles` | + `receipt_prefix` |
| `commerce_items` | + `billing_interval` |
| `commerce_subscriptions` (nova) | conta, contato, negócio, item, quantidade, preço, moeda, ciclo, situação, `current_period_start` e `current_period_end`, `cancel_at_period_end`, `canceled_at`, provedor, `external_id`, `public_token`, idioma |

## Webhooks e segurança

- **Rota única:** `/commerce/webhooks/:provider/:webhook_token`. O token acha o provedor da conta, a assinatura é verificada com o segredo **dele** e só então se toca no banco. Assinatura inválida devolve 401 e o corpo não vai para o log.
- **Stripe:** `Stripe::Webhook.construct_event`. O webhook é criado pela própria API do Stripe ao conectar, e o segredo é guardado sozinho.
- **Mercado Pago:** verifica `x-signature` (HMAC-SHA256) e depois consulta o pagamento ou a assinatura pela API, que é a fonte da verdade.
- **Yappy:** verifica o hash do IPN, que aqui é **obrigatório**. O `cortex-tasty-hub` serve só de referência de endereços e fluxo. As quatro falhas de lá ficam corrigidas: credencial em texto puro, webhook aberto, hash opcional e retorno confiando na URL.
- **Credenciais** nunca voltam pela API; a tela mostra só os 4 últimos caracteres.

## Ordem de entrega

1. **3a (1.14.0): Stripe avulso + recibo.**
   - Provedores, botão Pagar com valor parcial, webhook e conciliação.
   - O documento **recibo**, inclusive para o pagamento manual.
   - É o caminho mais curto para provar o fluxo inteiro em modo teste.
2. **3b (1.15.0): Mercado Pago** avulso, com Pix pelo Checkout Pro.
3. **3c (1.16.0): Yappy** avulso.
4. **3d (1.17.0): assinaturas.** Stripe Billing, preapproval do MP, cobrança assistida pelo Yappy e a tela Assinaturas.

Cada entrega tem smoke próprio, com o provedor falso via `class_eval`. Os cenários cobrem assinatura do webhook válida e inválida, aviso repetido, valor parcial, fatura anulada, recibo gerado e enviado, e ciclo de assinatura pago e falho.

## Perguntas que restam (com o que eu faria se não houver resposta)

1. **Pix:** pelo Checkout Pro do Mercado Pago, sem QR na nossa página. (padrão: sim)
2. **Pagar cotação:** só fatura se paga online. Para cobrar antes, gera-se a fatura a partir da cotação aceita, como hoje. (padrão: só fatura)
3. **Taxa do provedor:** a empresa absorve, sem repassar ao cliente. (padrão: absorve)
4. **Mínimo do pagamento parcial:** 1 unidade da moeda, ou um percentual/valor configurável na empresa. (padrão: 1 unidade)
5. **Teste grátis na assinatura:** fora do primeiro corte. (padrão: fora)
6. **Primeira cobrança da assinatura:** na hora da adesão, e a data de renovação passa a ser o dia da adesão. (padrão: sim)
