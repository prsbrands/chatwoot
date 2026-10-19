# Online payments and subscriptions

Let customers pay invoices online, in full or in part, and charge monthly or yearly plans automatically. The payment is recorded, the invoice is updated and the receipt is sent without anyone on your team touching it. The providers are connected in **CRM → Catalog → Company & payments → Online payments**, and the subscriptions live in the menu under **CRM → Subscriptions**.

*Also in: [Español](comercial-cobranca.es.md) · [Português](comercial-cobranca.pt.md)*

*Commerce module: [Catalog and company](comercial-catalogo.en.md) · [Quotes and invoices](comercial-documentos.en.md) · [Public catalog page](comercial-vitrine.en.md)*

## Before you start

1. **Commerce turned on** for your account (an administrator of the installation does this in the Super Admin, by ticking **Commerce** in the features of the account).
2. **An account of your own at the provider.** The money goes straight to your account there.

| Provider | Account | Currencies | What the customer uses | What you paste in the system |
|---|---|---|---|---|
| Stripe | A Stripe account | USD, EUR, BRL | The payment page hosted by Stripe | The secret key |
| Mercado Pago | Mercado Pago **Brasil** only | BRL | Card, Pix, boleto or Mercado Pago balance, on the Mercado Pago page | The Access token |
| Yappy | Yappy Comercial (Botón de Pago) | USD | Approving the payment in the Yappy app | Merchant ID, Secret key and, if needed, the domain |

3. **Try in test mode first.** Every provider can be connected as **Test mode** and later switched to **Live** with the live keys (**Change key**).
4. **A payment method linked to the provider** (step 2 below) and **kept ticked on the invoice**.
5. **The currency of the invoice.** The customer is only offered the providers that accept it: an invoice in BRL shows Mercado Pago and Stripe, one in USD shows Stripe and Yappy, one in EUR shows Stripe.
6. **The public address of the installation.** The providers confirm payments by calling it. If your installation is not reachable from the internet, confirmations never arrive.
7. **Who can do what.** Administrators connect and disable providers and cancel subscriptions. The whole team creates subscriptions and sends their link.

## Step by step

### 1. Connect a provider
**Company & payments → Online payments**. Each provider has its own card. Press **Connect**, choose the **Environment** (**Test mode** or **Live**), fill in the credentials and press **Connect** again. You see "Stripe connected." (or the name of the provider). The card then shows **Active**, "Test mode · key …1a2b" (only the last 4 characters are ever shown) and the currencies.

- **Stripe.** In the Stripe Dashboard, Developers, API keys, copy the **secret key** (not the publishable one) or a restricted key with write access to Checkout Sessions and Webhook Endpoints. It must match the environment: `sk_test_` or `rk_test_` in Test mode, `sk_live_` or `rk_live_` in Live. The payment webhook is created for you; there is nothing to register.
- **Mercado Pago.** In Mercado Pago Developers, Your integrations, your application, Production credentials (or the test ones), copy the **Access token** (not the Public key). Only Mercado Pago Brasil accounts are accepted. A token that starts with `TEST-` opens the test checkout.
  - **Webhook secret signature (optional):** if you set a secret in Your integrations, Webhooks, paste it here for an extra check. Without it every notice is still confirmed by reading the payment from Mercado Pago.
  - **For subscriptions this step is required.** The card shows the **Webhook URL**. In Mercado Pago, Your integrations, your application, Webhooks, **production mode**, register that URL with the events **Payments** and **Plans and subscriptions**. Without it, subscription charges are not recorded here.
- **Yappy.** In Yappy Comercial, Botón de Pago, copy the **Merchant ID** and the **Secret key**, and register the address of the installation (or the domain you type in **Domain registered in Yappy (optional)**) as the payment domain. Only USD.

The key is stored encrypted and never shown again. **Change key** replaces it. **Disable** pauses the provider (its payment methods stop showing the Pay button) and **Enable** brings it back; payments already made stay in the history.

### 2. Link a payment method to the provider
**Company & payments → Payment methods**, create or edit a method and choose the provider in **Online charge**. The list then reads "Online with Stripe". If the provider is connected but no active method uses it, its card warns "No active payment method uses Stripe yet, so invoices show no Pay button…".

In each invoice, the method must stay ticked under "Payment methods shown on this document" (marked "(Pay button)"). The name of the method is the text of the button, "Pay with …", so give it a clear name, such as "Card" or "Yappy".

### 3. What the customer does
On the invoice link (or the "Pay online" button of the email) the customer finds **Pay online**, with **Amount to pay** already filled with the balance and one button per method.
- The customer can pay **less than the balance**: at least 1 unit of the currency, or the whole balance when it is under 1.
- **Stripe and Mercado Pago:** the button opens the page of the provider; after paying, the customer returns to the invoice. The page says that the payment is being confirmed, refreshes by itself and then thanks the customer and announces the receipt.
- **Yappy:** the customer types the 8-digit **Yappy phone** and presses the button. The page asks to accept the request in the Yappy app and refreshes by itself when the payment is confirmed. After 10 minutes without a confirmation, the page says the confirmation may take a few more minutes and offers a link back to the invoice.
- If the payment is declined or the request expires, the page says so and the customer can try again. If the payment cannot even start (amount out of range, wrong phone, provider refused), the page asks to check the amount and try again.

The texts of the page are in the language of the document.

### 4. What happens on your side
Only a confirmation from the provider counts (the notice it sends, or the answer when the system asks it). The customer coming back to the page proves nothing by itself. When it arrives:
- The invoice gets the payment (with the "Online" mark) and becomes **Partially paid** or **Paid**.
- The receipt `REC-…` is issued and sent through the conversation and the last email used on the invoice.
- If the invoice has a conversation, a private note says "Online payment received: …" with the amount, the invoice, the method and the receipt.
- When the invoice is **Paid**, the open deal of the contact moves to Won.
- The same notice arriving twice never pays twice.

### 5. Delays and the safety net
- Every 5 minutes the system asks the provider about the attempts that got no answer (after 2 minutes) and applies what it finds. An attempt that is still unpaid after 24 hours expires. A customer returning from the provider's page also triggers a check.
- Yappy cannot be queried: its confirmation only arrives as a notice, and an attempt without one expires after 24 hours.
- Refunds are made in the panel of the provider. The system does not record them, and a payment that came online cannot be removed from the invoice.

### 6. Create a subscription
A subscription needs a **plan**: a catalog item with **Billing** set to Monthly plan or Yearly plan (see [Catalog and company](comercial-catalogo.en.md)).

**CRM → Subscriptions → New subscription**:
- **Customer:** search and pick a contact.
- **Plan:** the available plans, each with its price.
- **Quantity:** starts at 1; the charge is the price times the quantity.
- **Payment method:** only active methods charged online by Stripe, Mercado Pago or Yappy. Stripe (USD, EUR, BRL) and Mercado Pago (BRL) charge automatically. Yappy (USD) has no automatic debit, so each renewal invoice is sent 3 days before the due date with the payment link.

Press **Create**. The price, currency and cycle are copied from the plan, so later changes in the catalog do not affect this subscription. The details open on their own.

### 7. Send the link to the customer
A new subscription is **Awaiting customer** and shows its link. Either **Copy link** and send it as you prefer, or choose the conversation and press **Send link to this conversation**. That conversation also becomes the one used for receipts and notices of the subscription. The customer's email on the contact is used too, when it is valid.

The customer opens the page "Subscription · plan name" with the price per month or year and a **Subscribe with …** button:
- **Stripe:** opens the Stripe payment page. The first charge happens right away.
- **Mercado Pago:** the page first asks for the **Email of your Mercado Pago account**, then opens Mercado Pago to authorize the subscription.
- **Yappy:** opens the invoice of the first cycle, due today, and the customer pays it with the Yappy phone, as any invoice.

When the customer comes back, the page says the subscription was received and the receipt of the first payment is on its way.

### 8. How each cycle is charged

| Provider | How it charges | What you get in the system |
|---|---|---|
| Stripe | Automatically, every month or year | A paid invoice for the period and the receipt, sent. If a charge is declined, the subscription becomes **Past due** with a private note, and Stripe tries again |
| Mercado Pago | Automatically, with the card authorized by the customer. Needs the webhook registered in step 1 | The same: paid invoice and receipt, or **Past due** when declined |
| Yappy | Assisted: 3 days before the end of the period the invoice of the next cycle is created, due at the end of the period, and its link goes by the subscription's conversation and the customer's email. On the due day a reminder goes by chat | Paying that invoice renews the subscription. Unpaid 5 days after the due date, the subscription becomes **Past due** with a private note |

The subscription becomes **Active** when its first cycle is paid. A **Past due** subscription goes back to **Active** when a renewal is paid.

### 9. Follow and cancel
- The list shows the plan, the customer, "Renews on {date}" or "Ends on {date}", the price per month or year and the status: **Awaiting customer**, **Active**, **Past due** or **Canceled**. Filter by status and search by plan or customer.
- Click a subscription to see its **Invoices**: number, period, receipts, total and status. Click an invoice to open it. They are also in **Quotes & invoices**.
- **Cancel at period end** (administrators): the customer keeps what was paid and no new cycle is charged. On Mercado Pago, charging stops at once and the subscription stays **Active** here until the paid period ends. **Cancel now**: ends the subscription immediately and voids the open renewal invoice. Both ask for a second click ("Click again to confirm").
- A subscription still **Awaiting customer** is always cancelled at once.
- If a customer asks to cancel by chat, an administrator does it here. The AI does not cancel subscriptions.

### 10. When the AI assistant sells
If the AI assistant of the account sells from the catalog and a customer says which plan they want, the assistant creates the subscription (or reuses the pending one for that plan) and sends the link in the conversation. For that, the plan must be **Available** and there must be an active payment method whose provider charges subscriptions in the currency of the plan.

## When something fails or does not show

| What you see | What to do |
|---|---|
| "The secret key does not match the sandbox environment" (or production) | The key and the environment disagree: **Test mode** is "sandbox" and takes `sk_test_` or `rk_test_`; **Live** is "production" and takes `sk_live_` or `rk_live_` |
| A message from Stripe when connecting | The key is wrong, revoked or without the permissions listed in step 1 |
| "This Mercado Pago account is …; only Mercado Pago Brasil (BRL) is supported" | Use the credentials of a Brazilian account |
| "Mercado Pago: HTTP 401 …" | The Access token is wrong or expired. Copy it again |
| "Invalid Yappy secret key" or "Yappy: … (code)" | The Merchant ID, the Secret key or the domain do not match what is registered in Yappy Comercial |
| "Something went wrong. Try again." | A generic failure, also shown when the provider refuses to cancel a subscription. Check the panel of the provider and try again |
| The customer sees no pay button | The invoice is a draft, paid or void, has no balance, the method is unticked or inactive, the provider is disabled, or the provider does not accept the currency of the invoice |
| The customer paid but the invoice did not change | Wait a few minutes: the safety net checks every 5. If it does not change, look at the webhook deliveries in the provider's panel. An answer 400 means the signature did not match (check the Webhook secret signature on Mercado Pago, or the Secret key on Yappy); an answer 404 means the address is not the one the system gave (the Webhook URL on the Mercado Pago card) |
| The Yappy customer sees "The payment was declined or the request expired…" | Ask the customer to try again, typing the 8-digit phone registered in Yappy |
| "Provider is invalid" when creating a subscription | The provider of that payment method does not accept the currency of the plan: use Stripe for USD, EUR or BRL, Mercado Pago for BRL, Yappy for USD |
| The customer sees "We could not start the subscription…" | The subscription is no longer open (already active or cancelled), the provider refused it, or on Mercado Pago the email is invalid. Create a new link if needed |
| A subscription charge appeared at Mercado Pago and not here | The webhook with the events Payments and Plans and subscriptions is missing in the Mercado Pago panel (step 1) |
| A subscription is **Past due** | The last renewal was declined or is unpaid. The customer must fix the card or pay the renewal invoice |

## Not included
- No refunds or chargebacks recorded in the system; they are handled in the provider's panel.
- No fee pass-through to the customer: the company absorbs the fee of the provider.
- Only invoices are paid online; a quote cannot be paid until it becomes an invoice.
- Only one connection per provider in each account, and only Stripe, Mercado Pago and Yappy.
- No free trial, coupons or change of plan with proportional charge: to change a plan, cancel and create a new subscription.
- No Pix QR code on our page: Pix is offered inside the Mercado Pago page.
- No list of subscriptions in the contact card.
- No automatic reminder for unpaid invoices, except the Yappy renewals.
