# Comercial — catálogo, orçamentos, faturas e cobrança

Módulo do CortexGen Chat (MIT, código nosso) para vender a partir das conversas. É multiempresa e multinegócio: comércio e serviço, preço fixo ou sob orçamento, várias moedas e documentos em três idiomas.

Flag por conta: **`commerce`**, no fim de `feature_flags_ext_1`. Liga no Super Admin.

| Fase | O quê | Versão | Situação |
|---|---|---|---|
| 1 | Catálogo, empresa e formas de pagamento | 1.12.0–1.12.1 | No ar |
| 2 | Orçamentos e faturas com PDF, link público, envio, pagamentos, arquivar e reabrir | 1.13.0–1.13.2 | No ar |
| 3a | Stripe: fatura paga online (inteira ou parte), recibo como documento | 1.14.0 | Pronta; desenho em `comercial-fase3.md` |
| 3b | Mercado Pago Brasil: Checkout Pro (Pix, cartão, boleto, saldo), BRL | 1.15.0 | Pronta |
| 3c | Yappy (Botón de Pago V2), USD | 1.16.0 | Pronta |
| 3d | Assinaturas mensais/anuais | — | Próxima |
| 4 | Catálogo na IA (4a) e vitrine pública (4b) | 4a: 1.18.0; 4b: 1.19.0 | Entregue |

## Decisões do Paulo (05/10/2026)

- A fatura é **comercial**, não fiscal. NF-e e factura electrónica da DGI ficam fora.
- **Um preço com uma moeda** por item. Moedas: USD, BRL e EUR. O preço é opcional: sem preço, o item é "sob orçamento".
- Os documentos saem em **espanhol, português ou inglês**, escolhido por documento, porque uma conta atende clientes em vários países.
- Impostos por **alíquota em cada linha**, com o modo do documento: sem imposto (soma por fora), com imposto incluso ou isento.
- Numeração **`COT-2026-0001`** / **`FAT-2026-0001`**, por tipo e por ano, com o prefixo editável na empresa.
- Os dados fiscais do cliente ficam **lembrados no contato**.
- Envio pela **conversa** e por **e-mail**. **Todo PDF gerado fica arquivado** no documento.
- **Arquivar** é manual: o documento sai da lista e vai para Arquivados.
- **Excluir** só vale para rascunho.
- **Reabrir para edição** volta o documento a rascunho. Fatura com pagamento não reabre.

## Dados

Os models ficam em `app/models/commerce/` e o prefixo das tabelas é `commerce_`.

| Tabela | Para quê |
|---|---|
| `commerce_categories` | Categorias do catálogo |
| `commerce_items` | Produto ou serviço, com tipo, SKU, `price` opcional, `currency`, `unit` e `available`. `billing_interval` (`one_time`, `month`, `year`): mensal ou anual é **plano** de assinatura e exige preço. As imagens ficam no ActiveStorage (`images`, até 10) |
| `commerce_profiles` | Uma linha por conta, criada na primeira leitura (`Profile.for`). Guarda logo, nomes, documento fiscal, contatos, moeda padrão, condições, rodapé e prefixos |
| `commerce_payment_methods` | Formas de pagamento aceitas, com tipo e instruções ao cliente. Com `provider_id`, vira cobrança online (o botão "Pagar") |
| `commerce_payment_providers` | Provedor conectado pela conta (`stripe`; `mercado_pago` e `yappy` depois): ambiente sandbox/production, `credentials` (JSON) e `webhook_secret` **cifrados**, `webhook_token` que vai na URL do webhook, `webhook_endpoint_id` |
| `commerce_checkouts` | Cada clique em "Pagar": documento, provedor, forma, valor, moeda, situação (pending/paid/failed/expired), `external_id` (sessão do Stripe, único por provedor), `checkout_url` |
| `commerce_documents` | Orçamento, fatura ou recibo (`kind` 0/1/2). `payment_method_ids` são as formas que o documento mostra (página, PDF, e-mail e `/pay`); nasce com todas as ativas. O recibo guarda em `details` o valor, a forma, a data e a posição da fatura (total, pago até ali, saldo); `delivered_email` é o último e-mail usado no envio. Tem `number`/`year`/`sequence`, `status`, `language`, `currency` e `tax_mode`. Liga ao contato, negócio, compromisso, conversa e documento de origem. Guarda **cópias** `customer` e `company` (jsonb), totais, textos, datas de cada passo, `archived_at`, `public_token` e os PDFs no ActiveStorage (`pdfs`) |
| `commerce_document_items` | Linhas do documento, copiadas do catálogo ou livres, com quantidade, unidade, preço (nulo = a cotar), desconto %, imposto % e os totais da linha |
| `commerce_document_payments` | Pagamentos recebidos: forma, valor, data e observação; `checkout_id` (único: o mesmo aviso não paga duas vezes) e `receipt_id` |
| `commerce_subscriptions` | Assinatura de um plano: **cópia** do plano (`name`, `unit_price`, `currency`, `interval` month/year) e do cliente (`customer`), `quantity`, contato, negócio, conversa, forma de pagamento e provedor; `status` (pending/active/past_due/canceled), `current_period_start/end`, `cancel_at_period_end`, `external_id` (a assinatura no provedor, única por provedor) e `public_token` (`/s/:token`). Cada ciclo pago vira uma fatura com `subscription_id`, `period_start` e `period_end` |

As migrations vão de `20261005000001` a `20261006000003`. `commerce_profiles` tem também `storefront_enabled` e `storefront_token` (a vitrine).

## Serviços

Ficam em `app/services/commerce/`.

- **`DocumentEditor`** salva cabeçalho, cliente e a lista inteira de linhas. Enquanto o documento pode ser editado (rascunho ou enviado), renova a cópia da empresa e recalcula os totais. Também grava `billing_tax_id_label`, `billing_tax_id` e `billing_address` no `additional_attributes` do contato.
- **`DocumentTotals`** calcula os três modos de imposto. Bruto = quantidade × preço; líquido = bruto − desconto. No modo *exclusive*, o imposto é o líquido × alíquota. No *inclusive*, é líquido − líquido / (1 + alíquota). A tela tem a mesma conta em `constants.js`, mas só como prévia.
- **`DocumentPdf`** gera o PDF com **Prawn 2.4**, que no Ruby 3.4 precisa da gem `matrix`. Usa as fontes embutidas (Windows-1252): o que não cabe vira "?". O logo é convertido para PNG pelo vips.
- **`DocumentFlow`** cuida dos passos do documento:
  - `archive_pdf!` gera o PDF e o guarda no arquivo do documento;
  - `mark_sent!`, `accept!`, `decline!`, `void!`, `reopen!`, `archive!` e `unarchive!` mudam a situação;
  - `to_invoice!` cria a fatura copiando o orçamento;
  - `add_payment!` e `remove_payment!` registram pagamentos e chamam `settle!`, que soma os pagamentos, define parcial ou paga e, quando paga, marca o negócio como **ganho** com o valor da fatura.
- **`DocumentSender`** envia o documento:
  - pela **conversa**, com o `Messages::MessageBuilder` e o blob do PDF como anexo, mais o link;
  - por **e-mail**, com o `Commerce::DocumentMailer`, em HTML com a marca da empresa, logo `cid:` e PDF anexo.
  
  Canal API sem webhook, como a caixa de voz, recusa o envio.
- **`CheckoutStarter`** (página pública → "Pagar") valida o valor no servidor (de 1 até o saldo; abaixo de 1, só o saldo), a forma online e a moeda, cria o checkout e abre a sessão no provedor.
- **`Gateways::MercadoPago`** usa o Access token da conta (HTTParty). `connect!` aceita só conta Brasil (`site_id` MLB). `start!` cria a preferência do Checkout Pro, com `notification_url` = webhook do provedor e `external_reference` = id do checkout. `webhook` lê o pagamento na API (a fonte da verdade) e confere o `x-signature` quando há chave secreta. `status` busca por `external_reference`.
- **`Gateways::Yappy`** valida o comércio (`validate/merchant`) e cria a ordem (`payment-wc`) com o celular do cliente (`aliasYappy`). Só o IPN (GET) confirma, com o hash HMAC-SHA256 obrigatório; não há consulta de situação.
- **`Gateways::Stripe`** usa a chave da própria conta (`Stripe::StripeClient`): `connect!` valida a chave e cria o webhook (eventos `checkout.session.*`), `start!` abre a Checkout Session, `status` consulta e `webhook` verifica a assinatura (`Stripe::Webhook.construct_event`).
- **Assinaturas (1.17.0, só Stripe):** `SubscriptionBilling#start!` abre a Checkout Session no modo `subscription` (`price_data` com `recurring`, sem catálogo no Stripe; `subscription_data.metadata.cortexgen_subscription_id`). O Stripe Billing cobra os ciclos. No webhook, `invoice.paid` → `cycle_paid!`: fatura do período (enviada, com a linha da assinatura) + checkout com o id da fatura do Stripe (o aviso repetido acha o mesmo checkout) + `CheckoutSettler` (pagamento, recibo, nota, negócio ganho). `invoice.payment_failed` → `past_due` + nota; `customer.subscription.deleted` → `canceled`. A assinatura do Stripe é achada pelo `external_id` ou, no primeiro aviso, pelo metadata (`subscriptions.retrieve`). O id dela vem em `invoice.parent.subscription_details.subscription` nas versões novas da API e em `invoice.subscription` nas antigas: o webhook usa a versão padrão da conta Stripe. A primeira assinatura acrescenta os eventos de Billing ao webhook das contas conectadas antes (`webhook_endpoints.update`). Cancelar: no fim do período (`cancel_at_period_end`) ou na hora (`subscriptions.cancel`).
- **Assinaturas no Mercado Pago (1.17.1, BRL):** `POST /preapproval` com `status: pending`, `external_reference` = `subscription-<id>` (com prefixo: o pagamento de cada ciclo também chega como aviso `payment` com esse valor, e sem o prefixo ele acharia um checkout pelo número) e o e-mail que o cliente digita na página (`payer_email`, obrigatório no Mercado Pago). O cliente conclui no `init_point`. **O preapproval não aceita `notification_url`:** os avisos de assinatura só chegam com a URL do webhook cadastrada no painel (Suas integrações → Webhooks, modo produção, eventos Pagamentos e Planos e assinaturas); o cartão do provedor diz isso. `subscription_preapproval` → `GET /preapproval/:id`: `authorized` liga (`external_id`), `cancelled` encerra (se não for cancelamento no fim do período). `subscription_authorized_payment` → `GET /authorized_payments/:id`: `payment.status` aprovado vira ciclo pago (período a partir do `debit_date`, +1 mês ou +1 ano), recusado deixa em atraso. Cancelar é `PUT /preapproval/:id {status: cancelled}`, que para de cobrar já; com cancelamento no fim do período, o `Commerce::SubscriptionExpiryJob` (a cada 5 min) encerra quando o período pago acaba.
- **Assinaturas no Yappy (1.17.2, USD): cobrança assistida.** O Yappy não tem débito automático (`Subscription::ASSISTED`). "Assinar" cria a fatura do primeiro ciclo (vence hoje) e leva à página dela, onde o cliente paga com o celular, pelo fluxo de sempre. O `Commerce::SubscriptionCycleJob` (5 min) gera a fatura do ciclo seguinte 3 dias antes do fim do período (vence no fim do período) e manda o link pela conversa e pelo e-mail; no dia do vencimento, lembrete pela conversa (`details.reminded_on`); 5 dias depois sem pagar, `past_due` com nota. Cancelar na hora anula a fatura do ciclo sem pagamento. **Para os três provedores**, quem ativa a assinatura e avança o período é a fatura do ciclo paga (`DocumentFlow#paid!` → `SubscriptionBilling#invoice_paid!`), venha o pagamento do provedor, do link ou da mão.
- **Catálogo na IA (1.18.0, fase 4a):** atividade `catalog` do Jev (decidindo por padrão; `JevEntrada`, noul ≥ 0,6: produtos, serviços, preços, planos, orçamento ou assinar). O `MontaPrompt` lê `GET /commerce/bot/catalog` (`Commerce::AiSales#items`: os disponíveis, até 80, com preço, unidade, ciclo e `subscribable` quando há forma ativa cujo provedor cobra assinatura na moeda do plano) e põe a seção `# CATALOG` no prompt, com os ids, os únicos preços que a IA pode dar e duas etiquetas. `[[QUOTE <id>x<qtd>, ...]]`: o `Responde` chama `POST /commerce/bot/quotes`, que cria o **rascunho** da cotização com os preços do catálogo, o cliente (`Commerce.customer_of`), a conversa e o negócio aberto, e deixa nota interna mencionando o responsável do negócio (ou o primeiro admin) com o link; a equipe revisa e envia. `[[SUBSCRIBE <id>]]`: `POST /commerce/bot/subscriptions` cria (ou reaproveita a pendente) a assinatura e o `Responde` manda o link numa bolha depois da resposta. O `JevRevisao` trata as duas etiquetas como o `[[BOOK]]` (o sistema faz, sem a pergunta de promessa) e tem a rede `false_sale`: com o catálogo no prompt e sem etiqueta, resposta que promete cotização ou link vai para a equipe. Os nós do n8n têm teste fora do n8n: `node ops/n8n/test/catalogo.test.js`.
- **Vitrine pública (1.19.0, fase 4b):** `/c/:storefront_token` (`CommercePublicCatalogsController`), ligada em Company & payments (`commerce_profiles.storefront_enabled`; o token nasce na primeira vez e se mantém ao religar). Itens disponíveis com a primeira foto (variante até 640 px), categoria, preço com unidade ou ciclo do plano, ou "a cotizar"; filtro por categoria (`?category=`) e idioma (`?lang=`, senão o da conta). O botão de cada item abre `wa.me/<WhatsApp da empresa>` com "me interesa: <item>" (sem WhatsApp, `mailto:`); quem continua é a IA (fase 4a). Conta sem a flag `commerce` ou vitrine desligada: 404.
- **`CheckoutSettler`** aplica o resultado do webhook, da volta do cliente (`/d/:token?checkout=`) ou da conciliação. Faz isso com o checkout travado: pago vira `add_payment!` e, depois, o `Commerce::ReceiptJob`.
- **`ReceiptIssuer`** emite o recibo e o envia pela conversa e pelo último e-mail da fatura. No pagamento online, também deixa uma nota interna na conversa.
- **Jobs:** `Commerce::ReceiptJob`, `Commerce::CheckoutReconcileJob` (a cada 5 min, no `TriggerScheduledItemsJob`; expira o checkout depois de 24 h) `Commerce::SubscriptionExpiryJob` (a cada 5 min; encerra a cancelada no fim do período) e `Commerce::SubscriptionCycleJob` (a cada 5 min; cobrança assistida do Yappy).
- **`DocumentLabels`** guarda os textos que vão **dentro** do documento (PDF, página pública e e-mail) nos três idiomas, além de moeda, data e unidades. Ficam fora do i18n de propósito, porque o idioma é do documento e não de quem usa a tela.
- **`Commerce::Search`** (em `app/models`) faz a busca sem distinguir acento nem maiúscula, com o `translate()` do Postgres e sem extensão no banco.

## API e telas

- **API** (`/api/v1/accounts/:id/commerce/...`, sob a flag `commerce`):
  - `items`, com `POST images` e `DELETE images/:attachment_id`;
  - `categories`, `payment_methods` e `profile`;
  - `documents`, com as ações `pdf`, `deliver`, `accept`, `decline`, `void`, `to_invoice`, `reopen`, `archive`, `unarchive`, `payments` (com `send_receipt`), `payments/:id` e `payments/:id/receipt`;
  - `payment_providers` (index, create, update; só admin). Desligar é `active: false`;
  - `subscriptions` (index, show, create), com `deliver` (link pela conversa) e `cancel` (`at_period_end`, padrão true; só admin);
  - `bot/catalog`, `bot/quotes` e `bot/subscriptions`, para o bot do n8n (token de usuário da conta).
- **Permissões:** todos consultam. Itens, categorias, empresa e formas de pagamento só o admin altera. Nos documentos, todos criam, editam, geram e enviam; anular e mexer em pagamento é só do admin.
- **Página pública:** `/d/:token` (`CommercePublicDocumentsController < PublicController`), mais `/d/:token/pdf`, `/accept`, `/decline` e `/pay`. O rascunho dá 404. A da assinatura é `/s/:token` e `/s/:token/subscribe` (`CommercePublicSubscriptionsController`); as duas usam o estilo de `commerce_public_documents/_style`.
- **Webhook:** `POST /commerce/webhooks/:provider/:webhook_token` (`Commerce::WebhooksController`): token desconhecido 404, assinatura inválida 400.
- **Telas** (`app/javascript/dashboard/routes/dashboard/commerce/`):
  - `/catalog`: Catálogo, com categorias e editor do item com imagens;
  - `/company`: Empresa e pagamentos;
  - `/documents`: lista, com Quotes/Invoices, situação, busca e Arquivados;
  - `/documents/:id`: editor;
  - `/subscriptions`: lista por situação, nova assinatura e o detalhe (link, envio pela conversa, faturas e cancelamento).
  
  O menu fica no grupo CRM ("Quotes & invoices", "Subscriptions" e "Catalog"), e o hub "View all in CRM" tem os cartões das telas. A lista de conversas do cliente para envio é o `ConversationPicker`.

## Armadilhas já vividas

- **`@` no `en.json`** deixa a tela inteira em branco (vue-i18n lê como link). Escape `{'@'}`.
- **Anexo para o WhatsApp por QR:** o webhook precisa do **endereço direto** do arquivo. O adaptador do OpenWA não segue redirecionamento, por causa da sua proteção contra SSRF. Quem resolve é o `CortexgenMessage`, que no webhook troca o `data_url` pelo `download_url`.
- **Mesma rota com outro id** (orçamento → fatura): o Vue reaproveita o componente, então é preciso um `watch` no `documentId`.
- **E-mail:** o ApplicationMailer engole falha de SMTP. E o `email_continuity_on_api_channel` do Chatwoot manda a conversa por e-mail ao cliente; ele está desligado nas 3 contas e deve continuar assim.

## Testes

`ops/smoke/commerce.rb` (25 cenários), `ops/smoke/commerce_documents.rb` (41), `ops/smoke/commerce_checkout.rb` (41, com o Stripe falso por `class_eval` e a assinatura real do webhook), `ops/smoke/commerce_mercado_pago.rb` (18), `ops/smoke/commerce_yappy.rb` (24), `ops/smoke/commerce_subscriptions.rb` (32), `ops/smoke/commerce_subscriptions_mp.rb` (20) `ops/smoke/commerce_subscriptions_yappy.rb` (18) `ops/smoke/commerce_ai.rb` (15) e `ops/smoke/commerce_storefront.rb` (13) rodam no `ops/smoke/run.sh`, contra Postgres e Redis descartáveis. O e-mail fica em `:test`.
