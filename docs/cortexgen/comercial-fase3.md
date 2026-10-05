# Comercial, fase 3 — cobrança online (DESENHO, para o Paulo comentar)

Nada disto está codado. Os pontos marcados com **❓** dependem de uma resposta sua.

## O que o cliente vê

1. Recebe a fatura pelo WhatsApp ou por e-mail, com o link `/d/:token`.
2. A página pública e o e-mail ganham o botão **"Pagar"**, com o **saldo em aberto** (total − já pago).
3. Ao clicar, escolhe a forma: *Cartão* (Stripe), *Mercado Pago / Pix*, *Yappy*. Só aparecem as formas que aceitam a **moeda da fatura**.
4. Stripe e Mercado Pago: vai para o checkout do provedor e volta para `/d/:token`, que mostra "Pagamento em processamento" até o webhook confirmar. Yappy: digita o celular, aprova no app do Yappy, e a página espera a confirmação.
5. Confirmado, a página passa a "Paga", a fatura muda de situação e o negócio vira **ganho** (o `settle!` de hoje).

## O que a equipe vê

- **Company & payments** ganha a seção **Pagamentos online**: conectar Stripe, Mercado Pago e Yappy, cada um com ambiente *teste* ou *produção*, botão **Testar conexão** e o endereço do webhook para colar no painel do provedor (no Stripe, criamos o webhook pela API e guardamos o segredo sozinhos).
- Cada **forma de pagamento** pode apontar para um provedor conectado: é isso que a torna "online".
- No editor da fatura, o pagamento online aparece com o selo do provedor e o id externo. Pagamento online **não se apaga** pela tela (estorno fica fora; ver abaixo).
- Nota na conversa do cliente quando o pagamento entra (❓ e mensagem ao cliente também — ver perguntas).

## Dados

| Tabela | Colunas |
|---|---|
| `commerce_payment_providers` (nova) | `account_id`, `provider` (stripe/mercado_pago/yappy), `environment` (sandbox/production), `credentials` (texto **cifrado** com `encrypts`, JSON por provedor), `webhook_secret` (cifrado), `webhook_token` (aleatório, vai na URL do webhook), `active`. Único por conta + provedor |
| `commerce_payment_methods` | ganha `provider_id` (opcional) |
| `commerce_checkouts` (nova) | uma tentativa de pagamento: `document_id`, `provider_id`, `payment_method_id`, `amount`, `currency`, `status` (pending/paid/failed/expired), `external_id` (session/preference/order do provedor), `checkout_url`, `payload` (jsonb, última resposta), `paid_at`. Índice **único** em `provider_id + external_id` |
| `commerce_document_payments` | ganha `checkout_id` (único): o pagamento confirmado aponta para a tentativa |

Por que uma tabela de tentativas, e não só colunas novas no pagamento: quem clica em "Pagar" e desiste não pode virar pagamento, senão entra na soma do `settle!`. A tentativa guarda o vínculo com o provedor; o pagamento só nasce quando o provedor confirma, e o `checkout_id` único garante que o mesmo aviso, repetido, não paga duas vezes.

Credenciais nunca voltam pela API: a tela recebe só os 4 últimos caracteres.

## Provedores

| | Stripe | Mercado Pago | Yappy |
|---|---|---|---|
| Produto | Checkout Session (hospedado) | Checkout Pro (preferência): cartão, boleto, **Pix**, saldo MP | Botón de Pago V2 |
| Moedas | USD, EUR, BRL (❓ BRL depende da conta Stripe) | a do país da conta MP (BRL no Brasil) | USD |
| Cliente | gem `stripe` (já no Gemfile), `api_key` por chamada | HTTP direto (sem gem oficial Ruby mantida) | HTTP direto |
| Webhook | `checkout.session.completed` e `checkout.session.async_payment_succeeded`; assinatura `Stripe-Signature` por `Stripe::Webhook.construct_event` | aviso `payment`; assinatura `x-signature` (HMAC-SHA256 de `id:…;request-id:…;ts:…;`) e depois **`GET /v1/payments/:id`** como fonte da verdade (`approved`, `external_reference` = id da tentativa) | IPN `GET` com `orderId`, `status`, `domain`, `hash`; hash HMAC-SHA256 de `orderId+status+domain` com a 1ª parte da chave secreta decodificada, **obrigatório**; `E` = pago |

Rota única: `POST|GET /commerce/webhooks/:provider/:webhook_token`. O token acha o provedor da conta (sem expor o id da conta), a assinatura é verificada com o segredo **dele**, e só então se toca no banco. Assinatura inválida → 401, sem log do corpo.

Regras que valem para os três:
- O **valor e a moeda saem do servidor** (saldo da fatura na hora do clique), nunca da URL ou do formulário.
- A **volta do checkout não confirma nada**. Só o webhook confirma. Para não depender de um webhook atrasado, a página, ao voltar, pede ao provedor o estado daquela tentativa (Stripe `Session.retrieve`, MP `payments/search`) e um job a cada 10 min concilia tentativas pendentes das últimas 24 h.
- Valor confirmado diferente do esperado (fatura editada no meio) → entra como pagamento do valor **realmente pago**; o `settle!` decide parcial ou paga.
- Fatura anulada ou já paga: o botão some e o checkout é recusado.

### Yappy: o que não copiar do `cortex-tasty-hub`

O `supabase/functions/payment-gateway/index.ts` serve para os endereços, o fluxo `validate/merchant` → `payment-wc` e as mensagens de erro. Não serve para: credenciais em texto puro, `handleWebhook` que aceita qualquer payload, hash do IPN opcional e retorno do PagueloFacil confiando na URL. Aqui, os quatro ficam ao contrário.

## Fora desta fase

Estorno e reembolso (feitos no painel do provedor; o pagamento fica marcado à mão), assinatura/recorrência, pagar orçamento direto (❓), taxa repassada ao cliente (❓), PagueloFacil.

## Ordem de entrega

1. **3a — Stripe** (1.14.0): tabelas, seção Pagamentos online, botão Pagar na página e no e-mail, webhook, conciliação. É o mais rápido de provar: a gem já existe e o modo teste tem cartões de teste.
2. **3b — Mercado Pago** (1.14.x): Checkout Pro com Pix.
3. **3c — Yappy** (1.14.x).

Smoke novo, `ops/smoke/commerce_checkout.rb`, com o provedor falso por `class_eval` (como o Google): assinatura válida e inválida, aviso repetido, valor diferente, fatura anulada.

## Perguntas

1. **Contas:** quais existem hoje? Stripe (país da conta?), Mercado Pago (Brasil?), Yappy **comercial** (com `merchant_id` e chave secreta do Botón de Pago)?
2. **Pix:** só pelo Mercado Pago está bom, ou quer Pix direto (QR na própria página, sem sair para o MP)?
3. **Pagar orçamento:** só fatura paga online, ou um orçamento aceito pode ser pago e virar fatura sozinho?
4. **Parcial:** o cliente paga sempre o saldo inteiro, ou pode escolher um valor (sinal/entrada)?
5. **Taxa:** a empresa absorve (padrão), ou soma-se uma taxa ao cliente?
6. **Recibo:** ao confirmar, mandar recibo automático ao cliente pelo WhatsApp e/ou e-mail, ou só a nota interna na conversa?
