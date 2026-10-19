# Catalog and company: products, prices and payment methods

This is where you set up what you sell and the details printed on every quote, invoice and receipt: your products and services, your company data and the payment methods you accept. Find the catalog in the menu under **CRM → Catalog**. The company data and the payment methods are in **Company & payments**, opened with the button of that name at the top of the Catalog page.

*Also in: [Español](comercial-catalogo.es.md) · [Português](comercial-catalogo.pt.md)*

*Commerce module: [Quotes and invoices](comercial-documentos.en.md) · [Online payments and subscriptions](comercial-cobranca.en.md) · [Public catalog page](comercial-vitrine.en.md)*

## Before you start

1. **Commerce turned on** for your account (an administrator of the installation does this in the Super Admin, by ticking **Commerce** in the features of the account). With it on, **Quotes & invoices**, **Subscriptions** and **Catalog** appear in the menu under CRM.
2. **Who can do what.** Administrators create and change everything. Agents can open the Catalog to look things up and use the items in quotes and invoices, but they cannot edit items, and they cannot open **Company & payments**.
3. **A currency.** The module works in **USD**, **BRL** and **EUR**, and only those. Choose the one you use most as the default currency. Each item and each document still carries its own currency.
4. **A logo file** (PNG, JPEG or WebP), if you want your logo on the documents.
5. Online payments (Stripe, Mercado Pago, Yappy) are connected in the same **Company & payments** page, but they have their own manual: [Online payments and subscriptions](comercial-cobranca.en.md).

## Step by step

### 1. Fill in the company details
**CRM → Catalog → Company & payments** (administrators only; it is also in **View all in CRM**, under "Setting up the sale"). In the **Company details** block:

| Field | What to write |
|---|---|
| Logo | **Upload logo** (PNG, JPEG or WebP) or **Remove logo**. Printed on the PDF, the customer page and the email |
| Trade name | The name your customers know. Printed as the main name |
| Legal name | Printed below the trade name when it is different |
| Tax ID type / Tax ID | For example "RUC, CNPJ, EIN…" and the number |
| Phone, WhatsApp, Email, Website | Printed on the documents. The WhatsApp also feeds the button of the [public catalog page](comercial-vitrine.en.md) |
| Address | Printed under the company name |
| Default currency | USD, BRL or EUR. The currency of every new document |
| Default terms | Text copied into every new quote and invoice: validity, delivery time, payment conditions… |
| Footer | A line at the bottom of every document, for example "Thank you for your business." |
| Quote prefix / Invoice prefix / Receipt prefix | The start of the document numbers (COT, FAT and REC by default). See "Document numbers" below |

Press **Save**. You see "Company details saved."

- Each document keeps its **own copy** of the company data. The copy is refreshed every time you save a document that is still **Draft** or **Sent**. Accepted, paid or void documents, and PDFs already generated, do not change.
- **Default terms** and **Footer** are copied into a document when it is created. Changing them later only affects new documents.

### 2. Document numbers
Every document gets its number the moment it is created: prefix, year and a 4-digit sequence, for example `COT-2026-0001`, `FAT-2026-0001`, `REC-2026-0001`.
- The sequence is separate for quotes, invoices and receipts, and starts again at 0001 each year (the year is the issue date of the document).
- A prefix has 1 to 8 letters or digits and is saved in capitals. Changing it only affects new documents.
- A number cannot be edited by hand, and there is no setting to choose the next sequence number.

### 3. Taxes, currency and language
- **Taxes are not set here.** There is no company tax rate. Each document has a "Prices and taxes" choice and each line has a "Tax %" (see [Quotes and invoices](comercial-documentos.en.md)).
- **Currency** has a default here, but each document and each item has its own. Nothing is converted from one currency to another.
- **Language** is chosen per document (Spanish, Portuguese or English), not per company, because one account can serve customers in several countries. New documents start in the language of your account when it is one of the three, otherwise in Spanish.
- There is no time zone setting in this module: dates are plain calendar dates.

### 4. Payment methods
**Company & payments → Payment methods → New payment method**.

| Field | What it does |
|---|---|
| Name | What the customer reads, for example "Bank transfer — Banco General". It is also the text of the **Pay with** button when the method charges online |
| Type | Cash, Bank transfer, Pix, Yappy, Card, Payment link or Other. A label to keep things in order; it does not change how the method works |
| Online charge | Appears once an online provider is connected. "None (instructions only)" or the provider that charges the customer. See [Online payments and subscriptions](comercial-cobranca.en.md) |
| Instructions for the customer | Account number, Pix key, Yappy number… Printed on the PDF and on the customer page |
| Active | Only active methods can be shown on documents |

Press **Save**. Click a method in the list to edit it. An inactive method shows an "Inactive" mark. The list shows "Online with Stripe" (or the provider) on methods that charge online.

How the methods reach the customer:
- A new document starts with **all active methods ticked** under "Payment methods shown on this document". Untick the ones you do not want on that document.
- The customer page lists the methods **without** online charge, with their instructions. The methods **with** online charge become "Pay with …" buttons on invoices that have a balance.
- The PDF lists the name and instructions of every chosen method, except when the document is paid or void.

To delete a method, use the trash icon (or **Delete payment method** inside the method) and confirm "Delete {name}?". The method disappears from every document that showed it. A method that already has payments or online charges **cannot be deleted**: untick **Active** instead and it is hidden.

### 5. Categories
On the Catalog page press **Categories**.
- Type a name under "New category" and press **Add**.
- To rename, edit the name and click outside the field.
- The trash icon deletes a category. Its items stay without a category.
- A name has up to 80 characters.

### 6. Create an item
**Catalog → New item**.

| Field | What it does |
|---|---|
| Type | Product or Service |
| Category | One of your categories, or "No category" |
| Name | Required, up to 160 characters |
| Code (SKU) | Your own code, up to 60 characters |
| Description | Free text. Copied into the document line and shown on the public catalog |
| Price | Leave blank when it is quoted, measured or made to order: the item is then shown as "Price on request" |
| Currency | USD, BRL or EUR |
| Unit | unit, hour, day, week, month, m, m², m³, kg, liter, package, project or service |
| Billing | One-time, Monthly plan or Yearly plan. A plan is what customers subscribe to and **needs a price**. See [Online payments and subscriptions](comercial-cobranca.en.md) |
| Available | Unticked, the item shows an "Unavailable" mark and leaves the "Add from catalog…" list of documents, the plan list of subscriptions, the public catalog and the AI assistant |

Press **Save**. On a new item the window stays open with "Item created. You can add images now."
- **Images:** **Add images** takes PNG, JPEG or WebP, up to 10 per item ("Images (2 of 10)"). Hover an image and click the trash icon to remove it. The first image is the cover.
- **Edit:** click the item card (administrators).
- **Delete:** **Delete item**, then click again where it says "Click again to delete". Quotes, invoices and subscriptions already made keep their own copy.

The price on the card reads "price / unit" for one-time items, "price / month" or "price / year" for plans, and "Price on request" when there is no price.

### 7. Find items
On the Catalog page: the search box ("Search by name, code or description") ignores accents and capitals, then two filters, one for the type ("Products and services", Product, Service) and one for the category ("All categories").

### 8. Use the items in a quote or invoice
In the editor of a document, the **Add from catalog…** list shows the available items with their price. Picking one adds a line with the name, description, unit and price copied from the item. You can change the line freely; the catalog does not change.
- The price is copied as a number. **There is no currency conversion**: use items in the same currency as the document, or fix the unit price on the line.
- Free lines (**Add line**) do not need the catalog.

## When something fails or does not show

| What you see | What to do |
|---|---|
| "Something went wrong. Try again." | A generic failure. Try again; if it repeats, tell the administrator of the installation |
| "Quote prefix is invalid" (or Invoice prefix, Receipt prefix) | Use 1 to 8 letters or digits, no spaces or symbols |
| "Price can't be blank" when saving an item | Monthly and yearly plans need a price |
| "This payment method already has payments or online charges, so it stays in the history. Uncheck Active to hide it." | The method cannot be deleted. Untick **Active** |
| Clicking an item does nothing | Only administrators edit items |
| The item is missing from "Add from catalog…" | It is marked as not **Available** |
| There is no **Online charge** field in the payment method | No online provider is connected yet. See [Online payments and subscriptions](comercial-cobranca.en.md) |
| The logo is not on the documents | Use PNG, JPEG or WebP. Documents that were already saved with the old logo are updated the next time they are saved, if still Draft or Sent |

## Not included
- No spreadsheet import or export of the catalog: items are created one by one.
- No variations (size, color), no stock control and no tax per item.
- One price and one currency per item, no price lists and no automatic conversion.
- Items appear in alphabetical order; there is no manual ordering.
- One set of company details per account: no branches or several companies in the same account.
- The documents are commercial, not tax invoices. Electronic tax invoices (such as NF-e or the DGI electronic invoice) are not issued here.
