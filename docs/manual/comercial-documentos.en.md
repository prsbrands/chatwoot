# Quotes and invoices: create, send and follow

Create quotes, invoices and receipts with your branding in Spanish, Portuguese or English, send them by chat or email, let the customer accept a quote or pay an invoice on a link, and keep every PDF. Find it in the menu under **CRM → Quotes & invoices**.

*Also in: [Español](comercial-documentos.es.md) · [Português](comercial-documentos.pt.md)*

*Commerce module: [Catalog and company](comercial-catalogo.en.md) · [Online payments and subscriptions](comercial-cobranca.en.md) · [Public catalog page](comercial-vitrine.en.md)*

## Before you start

1. **Commerce turned on** for your account (an administrator of the installation does this in the Super Admin, by ticking **Commerce** in the features of the account).
2. **Company details filled in**: name, logo, tax ID, default terms and number prefixes. Every document copies them. See [Catalog and company](comercial-catalogo.en.md).
3. **Catalog items** are optional: a line can also be typed freely.
4. **To send by chat**, the customer must be a contact with a conversation on a channel that delivers messages to the customer (WhatsApp, for example). An inbox that only stores call transcripts does not deliver anything and is not offered. **To send by email**, you need the customer's email address, and the installation must be able to send email.
5. **To let the customer pay online**, connect a provider first. See [Online payments and subscriptions](comercial-cobranca.en.md).
6. **Who can do what.** The whole team creates, edits, generates PDFs, sends, marks quotes accepted or declined, creates invoices, reopens and archives. Only administrators can **Void**, **Delete draft**, record or remove payments and issue a receipt by hand.

## Step by step

### 1. Create the document
**CRM → Quotes & invoices**. The tabs **Quotes**, **Invoices** and **Receipts** switch the list. Press **New quote** or **New invoice**. A **Draft** is created right away, with its number (for example `COT-2026-0001`), today's date, the default currency, the default terms and footer of the company, and all active payment methods ticked.

Receipts cannot be created here: they come from payments (see step 11). To make an invoice from a quote, see step 9.

### 2. Fill in the customer
In the **Customer** block, type at least 2 letters in "Search a contact to fill in" and pick the contact: name, email, phone and the tax data remembered from earlier documents are filled in. Or type everything by hand: Name, Tax ID type, Tax ID, Email, Phone and Address.
- The tax ID and the address you type are remembered on the contact for the next document.
- Pick a contact if you want to send by chat. A document with no contact can only be sent by email.

### 3. Choose the document settings
In the **Document** block:

| Field | What it does |
|---|---|
| Document language | Spanish, Portuguese or English. The PDF, the customer page, the email and the chat text all use it |
| Currency | USD, BRL or EUR. Nothing is converted: the line prices are numbers in this currency |
| Prices and taxes | **Prices without tax (tax is added)**, **Prices include tax** or **Tax exempt**. See the example below |
| Issue date | Starts as today |
| Valid until (quote) / Due date (invoice) | Optional. After this date a sent quote shows **Expired** and an unpaid invoice shows **Overdue** |
| Payment methods shown on this document | The active methods of the company, all ticked. Those marked "(Pay button)" charge online |

Example with one line of 2 × 100.00, discount 10% and tax 7%:
- **Prices without tax:** Subtotal 200.00, Discount 20.00, Tax 12.60, **Total 192.60**.
- **Prices include tax:** the 180.00 after the discount already contains the tax. Total 180.00, "Tax included" 11.78.
- **Tax exempt:** the tax column disappears and the total is 180.00.

### 4. Add the items
In the **Items** block, pick from **Add from catalog…** or press **Add line** for a free line. Each line has the name and a description, **Qty**, **Unit**, **Unit price**, **Disc. %** and **Tax %** (not shown when the document is tax exempt), and the line total. The cross removes a line.
- A line with an empty unit price is shown to the customer as "Price on request" and counts as zero in the total.
- The totals on the screen (**Subtotal**, **Discount**, **Tax**, **Total**) are a preview while you type. After **Save**, the numbers calculated by the server are the ones that count.

### 5. Notes, terms and footer
At the bottom: **Notes**, **Default terms** (this is how the field is named in the editor) and **Footer**. They are printed on the PDF and on the customer page. The terms and the footer start with the company defaults and can be changed in each document.

### 6. Save, generate the PDF and keep the archive
- **Save** keeps your changes ("Saved.").
- **Generate PDF** saves first, creates a new PDF and opens it in a new tab.
- **PDF archive** lists every PDF ever generated for the document, with its date.
- **Send** always attaches the **most recent** PDF. If you changed the document after generating a PDF, press **Generate PDF** again before sending. (If the document has no PDF yet, one is made when you send.)
- The PDF supports Western European letters. Other characters, such as Cyrillic or emoji, are printed as "?".

### 7. Send it to the customer
Press **Send**. The window "Send COT-2026-0001" has two tabs.
- **Chat:** choose the conversation (the list shows the inbox, the number, the status and the last message), and optionally write a **Message**. The customer receives **two messages**: first the PDF alone, then a text with the link of the document. Without your own message, the text is the default one in the document language, with the customer's first name, the total (the balance on invoices) and the link.
- **Email:** **To** (starts with the customer's email), **Subject** and **Message**, both with a default in the document language. The customer receives an email with your logo, the number, the total and the deadline, a button to the document page ("Pay online" on invoices with online payment) and the PDF attached. Replies go to the company email.

When it is sent, a **Draft** becomes **Sent** and the document remembers the conversation and the email used. Receipts follow the same channels. You can send again at any time.

### 8. What the customer sees
The **Customer link** button (shown once the document is not a draft) opens the page the customer gets. A draft has no page. The page shows the company, the document, the lines, the totals, the payment methods without online charge with their instructions, the notes, the terms and the footer, in the document language.

| Button | English | Español | Português |
|---|---|---|---|
| Accept the quote | Accept quote | Aceptar cotización | Aceitar orçamento |
| Decline the quote | Decline | Rechazar | Recusar |
| Download the PDF | Download PDF | Descargar PDF | Baixar PDF |
| Pay online (invoices) | Pay with … | Pagar con … | Pagar com … |

The accept and decline buttons only exist on a **Sent** quote that has not expired. The pay button only exists on an invoice with a balance (see [Online payments and subscriptions](comercial-cobranca.en.md)).

### 9. When the customer answers
- **Accept quote / Decline** on the link turns the quote into **Accepted** or **Declined**, and the customer sees a confirmation on the page.
- If the quote was sent **through a conversation**, an internal (private) note appears in it, mentioning the owner of the deal (or the first administrator when there is no deal), with the total and a link to the document. The mention reaches that person as a notification in the bell. For an acceptance the note says to create the invoice. A quote sent only by email creates no note.
- Your team can answer in place of the customer with **Mark accepted** and **Mark declined**. These create no note and no automatic invoice.
- A quote past its **Valid until** date can no longer be answered on the link, but **Mark accepted** still works.

### 10. Create the invoice
- **Create invoice**, on a quote that is not Declined or Void, creates a new **Draft** invoice with the same customer, lines, texts and payment methods, and opens it. The quote becomes **Accepted** if it was not yet. The due date is not copied: set it on the invoice. Press the button **once**: each press creates another invoice.
- **Automatic invoice.** In **Company & payments → Automation**, tick "When the customer accepts a quote on its link, create the invoice and send it through the same channels as the quote (chat and email)". From then on, a customer who presses **Accept quote** gets the invoice created and sent by the same conversation and the last email used on the quote, and the internal note tells your team the invoice was created. It does not run for **Mark accepted**, it does not repeat if the quote already has an invoice, and it is off by default.

### 11. Invoices, payments and receipts
- An invoice becomes **Partially paid** when the payments received are less than the total, and **Paid** when they reach it. The **Payments received** block appears once the invoice is no longer a draft.
- **Online payments** register themselves, with an "Online" mark and the receipt number. See [Online payments and subscriptions](comercial-cobranca.en.md).
- **Record payment** (administrators) registers a payment received outside the system. Fields: **Amount** (starts with the balance), **Paid on**, **Payment methods**, **Note**, and the box **Issue and send the receipt**, ticked by default.
- When an invoice is **Paid**, the open deal of the contact in the Pipeline moves to Won, with the value of the invoice.
- The trash icon removes a payment recorded by hand (administrators). The invoice goes back to Sent or Partially paid and the receipt of that payment becomes **Void**. Online payments cannot be removed here: refund them in the provider's own panel, because the system does not record refunds.
- **The receipt** is a document of its own (`REC-2026-0001`) with the amount received, the method, the date, the invoice total, what was paid to date and the balance. It is sent through the invoice's conversation and the last email used on the invoice. If the invoice was never sent by chat or email, the receipt is created but not sent: open it in the **Receipts** tab and press **Send**. Next to a payment that has no receipt, administrators see **Issue receipt**.
- A receipt cannot change amount, method, customer or dates. You can change its language, notes, terms and footer, and generate its PDF again.

### 12. Archive, reopen, void and delete
- **Archive** takes the document out of the main list; the **Archived** button shows the archived ones, and **Unarchive** brings it back.
- **Reopen for editing** turns an **Accepted**, **Declined** or **Void** document back into a **Draft**. It is not available once the invoice has payments. The generated PDFs stay in the archive.
- **Void** (administrators) cancels a document that has no payments.
- **Delete draft** (administrators) deletes a draft for good; click again where it says "Click again to delete". Receipts cannot be deleted.
- A **Sent** document can still be edited, and the customer page shows the change at once. The PDF already sent does not change. An **Accepted**, **Declined**, **Partially paid**, **Paid** or **Void** document cannot be edited unless it is reopened.

### 13. Drafts prepared by the AI
If the AI assistant of the account sells from the catalog and a customer asks for a quote, the AI creates a **Draft** quote with the catalog prices, linked to the conversation, and leaves an internal note mentioning the owner of the deal (or the first administrator).
- The quote shows the mark **Prepared by AI** in the list and in the editor, and a red number appears next to **Quotes & invoices** in the menu, counting these drafts (it refreshes every minute).
- Open it: the banner says "The AI prepared this quote from conversation #… with the catalog prices. Review the items, quantities and customer, then send it." **Open the conversation** takes you to the chat.
- Review, change what you need and press **Send**. The number goes down.
- If the customer changes the request before you send, the AI updates the same draft and leaves a new note.

## Statuses and what moves them

| Document | Statuses |
|---|---|
| Quote | **Draft**, **Sent**, **Accepted**, **Declined**, **Void**. **Expired** is shown when a sent quote is past its "Valid until" date |
| Invoice | **Draft**, **Sent**, **Partially paid**, **Paid**, **Void**. **Overdue** is shown when a sent or partially paid invoice is past its due date; it can still be paid |
| Receipt | **Draft** (created, not sent yet), **Sent**, **Void** |

| Action | From | To | Who |
|---|---|---|---|
| Send | Draft | Sent | Team |
| Accept quote / Decline (customer link) | Sent quote | Accepted / Declined | Customer |
| Mark accepted / Mark declined | Draft or Sent quote | Accepted / Declined | Team |
| Create invoice | Draft, Sent or Accepted quote | Quote Accepted, new invoice in Draft | Team |
| Payment received | Sent or Partially paid invoice | Partially paid / Paid | Customer online, or administrators by hand |
| Remove payment | Partially paid or Paid invoice | Sent / Partially paid | Administrators |
| Reopen for editing | Accepted, Declined or Void | Draft | Team |
| Void | Any document with no payments, except receipts | Void | Administrators |

## When something fails or does not show

| What you see | What to do |
|---|---|
| "COT-2026-0001 is accepted and can no longer be edited" | The document is closed. Use **Reopen for editing** first |
| "COT-2026-0001 is declined: action not allowed" (or another status) | The action does not apply to that status, for example voiding a document that has payments, reopening a paid invoice or creating an invoice from a declined quote |
| "Inbox name does not deliver messages to the customer" | That conversation cannot reach the customer. Pick another conversation or send by email |
| "This customer has no conversation yet. Pick a contact on the document or send by email." | The document has no contact, or the contact has no conversation that delivers. Pick the contact in the **Customer** block or use the **Email** tab |
| The email says "Sent." but the customer does not receive it | The system does not show email delivery errors. Ask the customer to check the spam folder and ask the administrator of the installation to check the email setup |
| The customer sees old values in the PDF | **Send** uses the latest PDF. Press **Generate PDF** after editing and send again |
| The customer opens the link and finds nothing | The document is still a **Draft**. Send it first |
| The customer cannot accept or decline | The quote is not **Sent**, or its "Valid until" date has passed |
| **Delete draft**, **Void** or **Record payment** fail or are missing | They are for administrators only |
| No internal note appeared after the customer accepted | The quote was not sent through a conversation. The status changes anyway |
| The invoice created by the automatic option stayed in Draft | The quote had no conversation and no email to send through. Open the invoice and send it |

## Not included
- No tax invoices (NF-e, DGI electronic invoice): the documents are commercial.
- No electronic signature of the quote beyond the customer pressing **Accept quote**.
- No credit notes, refunds or automatic reminders for unpaid invoices (the only reminders are those of Yappy subscriptions).
- Numbers cannot be edited or reset by hand.
- No ready-made template other than the one PDF layout, which uses your logo, company data, notes, terms and footer.
- Receipts cannot be created from scratch: they always come from a payment of an invoice.
- A quote cannot be paid online: create the invoice first.
