# Public catalog page: your storefront

A public web page with the available items of your catalog, with photos and prices, that you can share on social media, in your bio or on your site. Each item has a button that opens a WhatsApp chat with your company about that item. You publish it in **CRM → Catalog → Company & payments → Public catalog**.

*Also in: [Español](comercial-vitrine.es.md) · [Português](comercial-vitrine.pt.md)*

*Commerce module: [Catalog and company](comercial-catalogo.en.md) · [Quotes and invoices](comercial-documentos.en.md) · [Online payments and subscriptions](comercial-cobranca.en.md)*

## Before you start

1. **Commerce turned on** for your account (an administrator of the installation does this in the Super Admin, by ticking **Commerce** in the features of the account). If it is turned off, the page stops working.
2. **Items in the catalog**, with the box **Available** ticked, and photos if you want a good-looking page. See [Catalog and company](comercial-catalogo.en.md).
3. **The company WhatsApp** filled in **Company details**, with the country code (for example +507 …). The button of each item opens that number. Only the digits count.
4. **Company data** you want visitors to see: logo, trade name, phone, email, website and footer.
5. **Who can do what.** Only administrators publish the page (**Company & payments** is for administrators).

## Step by step

### 1. Publish the page
**CRM → Catalog → Company & payments → Public catalog**. Tick **Publish the catalog page**. It takes effect at once, without pressing **Save**, and the link appears. (This tick also saves any other change you have typed in Company details.)

If WhatsApp is empty, you see "Fill in WhatsApp in the company data above: without it, the button opens an email to you instead." Without WhatsApp and without Email, the items show no button.

### 2. Share the link
The link has the form `…/c/` followed by a long code. Press **Copy link** ("Link copied") or click the link to see the page. Add `?lang=en`, `?lang=es` or `?lang=pt` to the end to force the language of the page; without it, the page uses the language of your account (Spanish when it is none of the three).

To take the page down, untick **Publish the catalog page**. The address then answers "not found" for everybody. The code of the link is created once and stays the same if you publish again; there is no button to generate a new one.

### 3. What the visitor sees
- The logo, the trade name, the phone, the email and the website of the company.
- The title **Catalog**, in the language of the page.
- When the available items belong to more than one category, a row of filters: "All" and one per category.
- A card per available item: the first photo (or an empty box), the category, the name, the price, the description (cut at 220 characters) and the button.
- The price reads "price / unit" for a one-time item, "price per month" or "price per year" for a plan, and "Price on request" for an item with no price.
- The company footer at the end.
- If nothing is available: "No products available right now."

### 4. What the visitor does
The visitor presses **I want this** (in Spanish "Lo quiero", in Portuguese "Quero este"). The button opens WhatsApp with your number and a ready message in the language of the page, such as "Hi, I am interested in: Item name". If there is no WhatsApp but there is an Email, it opens an email to the company with that message as the subject.

There is no cart, no checkout and no payment on the page.

### 5. Where the orders arrive
Nothing is registered on the page. The "order" is the conversation that begins on WhatsApp:
1. The message arrives in your inbox like any other customer message, if that WhatsApp number is connected as one of your inboxes.
2. Your team (or the AI assistant, if it sells from the catalog) answers. The AI can prepare a draft quote with the catalog prices or send the link of a subscription plan. See [Quotes and invoices](comercial-documentos.en.md) and [Online payments and subscriptions](comercial-cobranca.en.md).
3. Your team reviews and sends the quote, the invoice or the subscription link.

### 6. Keep it up to date
The page always shows the current catalog. Untick **Available** on an item to take it off the page, change the price in the item, add or replace photos (up to 10 per item; the page uses the first one). Changes show on the next time the page is opened.

## When something fails or does not show

| What you see | What to do |
|---|---|
| The link answers "not found" | **Publish the catalog page** is unticked, the code in the link is incomplete, or **Commerce** is turned off for the account |
| The page says "No products available right now." | No item has **Available** ticked |
| An item is missing | Check **Available** on that item |
| The item has no photo | Add images to the item in the Catalog |
| The button opens an email instead of WhatsApp | The **WhatsApp** field of Company details is empty |
| There is no button | Both **WhatsApp** and **Email** are empty |
| The WhatsApp chat opens with the wrong number | Fix the **WhatsApp** field, with the country code and only the real digits |
| The page is in the wrong language | Add `?lang=en`, `?lang=es` or `?lang=pt` to the link |
| There are no category filters | The filters only show when the available items belong to two or more categories |

## Not included
- No cart, checkout, online payment or stock on the page: every sale starts as a WhatsApp conversation.
- No orders list or order record: use the conversations, quotes and invoices.
- No search box, no page per item and no gallery (only the first photo of each item).
- No custom domain, colors or layout, and no way to generate a new link.
- No way to hide the price of one item other than leaving its price blank, which shows "Price on request".
- Plans appear with their price per month or year, but the button is the same WhatsApp button: the subscription is arranged in the conversation.
