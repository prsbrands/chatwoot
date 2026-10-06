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
| 4 | Catálogo na IA e vitrine pública | — | Depois da 3 |

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
| `commerce_items` | Produto ou serviço, com tipo, SKU, `price` opcional, `currency`, `unit` e `available`. As imagens ficam no ActiveStorage (`images`, até 10) |
| `commerce_profiles` | Uma linha por conta, criada na primeira leitura (`Profile.for`). Guarda logo, nomes, documento fiscal, contatos, moeda padrão, condições, rodapé e prefixos |
| `commerce_payment_methods` | Formas de pagamento aceitas, com tipo e instruções ao cliente. Com `provider_id`, vira cobrança online (o botão "Pagar") |
| `commerce_payment_providers` | Provedor conectado pela conta (`stripe`; `mercado_pago` e `yappy` depois): ambiente sandbox/production, `credentials` (JSON) e `webhook_secret` **cifrados**, `webhook_token` que vai na URL do webhook, `webhook_endpoint_id` |
| `commerce_checkouts` | Cada clique em "Pagar": documento, provedor, forma, valor, moeda, situação (pending/paid/failed/expired), `external_id` (sessão do Stripe, único por provedor), `checkout_url` |
| `commerce_documents` | Orçamento, fatura ou recibo (`kind` 0/1/2). `payment_method_ids` são as formas que o documento mostra (página, PDF, e-mail e `/pay`); nasce com todas as ativas. O recibo guarda em `details` o valor, a forma, a data e a posição da fatura (total, pago até ali, saldo); `delivered_email` é o último e-mail usado no envio. Tem `number`/`year`/`sequence`, `status`, `language`, `currency` e `tax_mode`. Liga ao contato, negócio, compromisso, conversa e documento de origem. Guarda **cópias** `customer` e `company` (jsonb), totais, textos, datas de cada passo, `archived_at`, `public_token` e os PDFs no ActiveStorage (`pdfs`) |
| `commerce_document_items` | Linhas do documento, copiadas do catálogo ou livres, com quantidade, unidade, preço (nulo = a cotar), desconto %, imposto % e os totais da linha |
| `commerce_document_payments` | Pagamentos recebidos: forma, valor, data e observação; `checkout_id` (único: o mesmo aviso não paga duas vezes) e `receipt_id` |

As migrations vão de `20261005000001` a `…04`.

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
- **`CheckoutSettler`** aplica o resultado do webhook, da volta do cliente (`/d/:token?checkout=`) ou da conciliação. Faz isso com o checkout travado: pago vira `add_payment!` e, depois, o `Commerce::ReceiptJob`.
- **`ReceiptIssuer`** emite o recibo e o envia pela conversa e pelo último e-mail da fatura. No pagamento online, também deixa uma nota interna na conversa.
- **Jobs:** `Commerce::ReceiptJob` e `Commerce::CheckoutReconcileJob` (a cada 5 min, no `TriggerScheduledItemsJob`; expira o checkout depois de 24 h).
- **`DocumentLabels`** guarda os textos que vão **dentro** do documento (PDF, página pública e e-mail) nos três idiomas, além de moeda, data e unidades. Ficam fora do i18n de propósito, porque o idioma é do documento e não de quem usa a tela.
- **`Commerce::Search`** (em `app/models`) faz a busca sem distinguir acento nem maiúscula, com o `translate()` do Postgres e sem extensão no banco.

## API e telas

- **API** (`/api/v1/accounts/:id/commerce/...`, sob a flag `commerce`):
  - `items`, com `POST images` e `DELETE images/:attachment_id`;
  - `categories`, `payment_methods` e `profile`;
  - `documents`, com as ações `pdf`, `deliver`, `accept`, `decline`, `void`, `to_invoice`, `reopen`, `archive`, `unarchive`, `payments` (com `send_receipt`), `payments/:id` e `payments/:id/receipt`;
  - `payment_providers` (index, create, update; só admin). Desligar é `active: false`.
- **Permissões:** todos consultam. Itens, categorias, empresa e formas de pagamento só o admin altera. Nos documentos, todos criam, editam, geram e enviam; anular e mexer em pagamento é só do admin.
- **Página pública:** `/d/:token` (`CommercePublicDocumentsController < PublicController`), mais `/d/:token/pdf`, `/accept`, `/decline` e `/pay`. O rascunho dá 404.
- **Webhook:** `POST /commerce/webhooks/:provider/:webhook_token` (`Commerce::WebhooksController`): token desconhecido 404, assinatura inválida 400.
- **Telas** (`app/javascript/dashboard/routes/dashboard/commerce/`):
  - `/catalog`: Catálogo, com categorias e editor do item com imagens;
  - `/company`: Empresa e pagamentos;
  - `/documents`: lista, com Quotes/Invoices, situação, busca e Arquivados;
  - `/documents/:id`: editor.
  
  O menu fica no grupo CRM ("Quotes & invoices" e "Catalog"), e o hub "View all in CRM" tem os cartões das três telas.

## Armadilhas já vividas

- **`@` no `en.json`** deixa a tela inteira em branco (vue-i18n lê como link). Escape `{'@'}`.
- **Anexo para o WhatsApp por QR:** o webhook precisa do **endereço direto** do arquivo. O adaptador do OpenWA não segue redirecionamento, por causa da sua proteção contra SSRF. Quem resolve é o `CortexgenMessage`, que no webhook troca o `data_url` pelo `download_url`.
- **Mesma rota com outro id** (orçamento → fatura): o Vue reaproveita o componente, então é preciso um `watch` no `documentId`.
- **E-mail:** o ApplicationMailer engole falha de SMTP. E o `email_continuity_on_api_channel` do Chatwoot manda a conversa por e-mail ao cliente; ele está desligado nas 3 contas e deve continuar assim.

## Testes

`ops/smoke/commerce.rb` (25 cenários), `ops/smoke/commerce_documents.rb` (36) `ops/smoke/commerce_checkout.rb` (41, com o Stripe falso por `class_eval` e a assinatura real do webhook) `ops/smoke/commerce_mercado_pago.rb` (18) e `ops/smoke/commerce_yappy.rb` (21) rodam no `ops/smoke/run.sh`, contra Postgres e Redis descartáveis. O e-mail fica em `:test`.
