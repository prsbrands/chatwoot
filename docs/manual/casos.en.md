# Cases: follow what the customer asked until it is solved

Cases keeps track of what a customer asked for and cannot be solved on the spot: a question that depends on someone in the company, a problem, a request, a complaint. Each case has a number, an owner, a due date and an outcome, and it can gather several conversations of the same customer. Find it in the menu under **CRM → Cases**.

*Also in: [Español](casos.es.md) · [Português](casos.pt.md)*

## Before you start

1. **Cases turned on** for your account (an administrator of the installation does this in the Super Admin, in the account's features, switch **Cases**). Without it the menu item, the **Cases** block in the conversation panel and the **Cases** tab of the contact do not appear.
2. **Who can do what.**

| | Agents | Administrators |
|---|---|---|
| See, open, edit and work on any case | Yes | Yes |
| See **Case metrics** | Yes | Yes |
| **Case settings** (types, due dates, details, AI, prefix) | No | Yes |
| **Delete case** | No | Yes |

3. **Case types.** The first time the account opens Cases, it receives five types in the language of the account (Portuguese, Spanish or English; any other language gets English). Rename them, change them or add your own in **Case settings** (step 1).

| English | Español | Português | Due in | Default priority |
|---|---|---|---|---|
| Question | Duda | Dúvida | 24 h | Normal |
| Problem | Problema | Problema | 8 h | High |
| Request | Solicitud | Solicitação | 48 h | Normal |
| Complaint | Reclamo | Reclamação | 4 h | High |
| Billing | Financiero | Financeiro | 24 h | Normal |

4. **Due dates count calendar hours**, not business hours, from the moment the case is opened. They are shown in the time zone of your browser.
5. **To let the AI open cases and answer through the assistant** you also need: a persona answering at least one inbox (AI agent → Personas), **Jev** turned on with its key (AI agent → Jev), and the installation administrator keeping the n8n workflow "CortexGen Caso" published. Step 6 and step 7 explain each one. The rest of Cases works without any of this.
6. **Numbers to know.**

| What | Value |
|---|---|
| Case number | `PREFIX-YEAR-0001`, counting from 1 again each year (for example `CAS-2026-0001`) |
| Prefix | 1 to 8 letters or digits, always in capitals; `CAS` until you change it |
| Cases on the list | 100 at a time, then **Show more** |
| Description, note, "What was done" | up to 5,000 characters |
| Message sent through the assistant | up to 2,000 characters |
| "When is it this type?" | up to 500 characters |
| Minimum confidence for the AI to pick a type | 80% |
| Replies sent through the assistant | up to 5 per minute for the whole account |

## Step by step

### 1. Set up your case types (administrators)
**Cases → Case settings.**

- **Number prefix:** type the letters and press **Save**. It only changes new cases; numbers already given stay as they are.
- **Case types:** the list shows each type with its due date, priority, number of details, and whether the AI opens it or the customer is notified. Use the arrows to change the order, the pencil (**Edit type**) to edit and the trash can (**Delete type**) to delete. A type that already has cases cannot be deleted: turn off **Available for new cases** instead.
- **New type** (or the pencil) opens a window with:

| Field | What it does |
|---|---|
| Name | How the type appears everywhere |
| Color | The dot that identifies the type in the list and the board |
| Due in (hours) | Whole hours, from 1. Counted from the moment a case of this type is opened. Blank: **No due date**. Changing it does not move the due date of cases already open |
| Default priority | Low, Normal, High or Urgent, used when the case is opened |
| Default assignee | The person who receives new cases of this type (Nobody: no one) |
| Available for new cases | Off: the type no longer appears when opening a case and the AI does not use it. Existing cases keep it |
| When the AI notices this kind of request | **The AI does not open this type**, **The AI opens it and keeps helping the customer** or **The AI opens it and hands the conversation to the team** (step 7) |
| When is it this type? | Appears when the AI is on for the type. Say in your own words what goes in this type, up to 500 characters (step 7) |
| Tell the customer the case number and when it is resolved | Sends the customer two notices in the case conversation (step 8) |
| Details of this type | Information your business needs for this kind of case. **Add detail** creates one: **Label**, **Kind** (Text, Number, Date, List or Yes / no), **Options** (only for List, separated by commas, at least one) and **Required to resolve**. **Remove detail** deletes it |

About details: the kind of a detail cannot be changed after it is saved. Renaming the label changes only the name on the screen. Removing a detail hides it, but cases that already had a value keep it in their data.

**Example: a "Warranty claim" type.** Name: Warranty claim. Due in: 48. Default priority: High. Default assignee: the head of support. Details: "Order number" (Text, required to resolve), "Problem" (List: Defective, Wrong item, Late) and "Photo received" (Yes / no). AI: **The AI opens it and keeps helping the customer**, with "When is it this type?": *A product arrived damaged or wrong, or stopped working under warranty*. Notice to the customer: on.

### 2. Open a case
There are three ways:

- **From a conversation:** in the right-hand panel, in the **Cases** block (it lists the customer's active cases), press **New case**. The case is born linked to that conversation, with the customer already filled in.
- **From a contact:** open the contact, tab **Cases** (it also lists resolved and canceled cases), press **New case**. The case has no conversation: link one later (step 4).
- **From the Cases page:** press **New case** and search the customer by name, phone or email (at least 2 letters). **Change** lets you pick another customer.

In the window **New case** fill in:

- **Type** (the first active type is already chosen) and **Title** ("What does the customer need?"); **Description** is optional.
- **Priority** and **Assignee** come from the type and can be changed.
- The **details** of the type appear below. Required ones are only demanded when resolving, not when opening.

Press **Open case**. The customer's most recently updated open deal is linked to the case automatically.

### 3. Find your cases
On **Cases** you see the active ones first, the closest due date at the top (overdue ones first, cases without a due date at the end).

- **Active / Resolved / Canceled** choose which group you see. Resolved and canceled show the most recently changed first.
- **Everyone / Mine / Unassigned** filter by assignee.
- **Overdue** shows only the late ones. The dropdowns **All types** and **All priorities** filter by type and priority.
- The search box (**Number, title or customer**) ignores accents.
- The icons **List** and **Board** (only on Active) switch between a list and three columns: Open, In progress and Waiting for customer.
- Each case shows its number, type, status, title, customer, priority, assignee and due date (**Due ...**, or **Overdue since ...** in red, or **Waiting for the customer** while the due date is paused).

A **red number** on **Cases** in the menu counts the overdue cases of the whole account, refreshed every minute (a case that is waiting for the customer is not counted as overdue). The **Risk radar** also shows "N cases are past their due date" at the top, with a link to each one.

### 4. Work on a case
Press a case to open it.

- **Top:** number, type, status, outcome (once resolved), **Overdue** and **Opened by the AI** when they apply. The pencil (**Edit**) next to the title changes the title and the description (**Save** / **Cancel**).
- **Buttons by status:**

| Status | Buttons |
|---|---|
| Open | **Start**, **Wait for customer**, **Resolve**, **Cancel case** |
| In progress | **Wait for customer**, **Resolve**, **Cancel case** |
| Waiting for customer | **Start**, **Resolve**, **Cancel case** |
| Resolved or Canceled | **Reopen** (goes back to In progress) |

- **Right column:** **Assignee**, **Priority**, **Type** and **Due date** change as soon as you choose. For the due date, type the date and time and leave the field; clearing it removes the due date. Changing the type later does not recalculate priority, assignee or due date. Below: the **Customer** (opens the contact), the **Deal** and **Conversations**.
- **Waiting for customer pauses the due date.** When you press **Start** again, the due date moves forward by the time the case stayed paused.
- **Details:** fill in the information of the type and press **Save**. The ones marked * are required to resolve.
- **History:** write an internal note and press **Add note**. Notes are only for the team; the customer never sees them. Below, in time order, everything that happened: who changed what and when, notes, what the AI did (author **AI**), automatic events (**System**) and what the customer answered (**Customer**).
- **Conversations:** each linked conversation opens when pressed. The other conversations of the same customer appear as **Link conversation #id**; press one to add it to the case.

### 5. Resolve or cancel a case
- **Resolve:** first fill in and save the required details; otherwise the screen says "Fill in ... before resolving the case." or "Save the details before resolving the case." In the window, choose the **Outcome** and, if you want, write **What was done** (it appears highlighted on the case).

| Outcome | Use it when |
|---|---|
| Solved | The customer's need was met (it is the default) |
| Not applicable | There was nothing to do |
| Duplicate | The same request already exists in another case |
| No response from the customer | The customer never answered |

- **Cancel case:** for a case opened by mistake or no longer needed. You can write **Why it was canceled**. It is kept in the list **Canceled**.
- **Delete case** (trash can, administrators): deletes the case and its whole history after a confirmation. Prefer canceling; deleting cannot be undone.

### 6. Reply to the customer through the assistant
Use it when the team knows the answer but you want the AI to say it, in the customer's language and tone. The block **Reply through the assistant** appears when the case is active and has a linked conversation.

1. Write what the customer must know (for example "The replacement ships on Monday and arrives in 3 business days.").
2. Press **Send answer**, or **Ask the customer** if you need something from them (an order number, a photo).
3. Within about a minute the AI posts it in the conversation, as the bot of that inbox, rewriting your text in the customer's language and tone, without adding any fact.

The result appears in **History** with one of these states:

| State | Meaning |
|---|---|
| waiting to be sent | Nobody picked it up yet. Normal for up to a minute. If it stays for long, the conversation may be in an inbox without a bot, or the workflow is stopped: tell the installation administrator |
| being sent | The AI is writing and posting it |
| sent | It is in the conversation. The text that went out also appears in the history |
| could not be sent | The post failed. The author is notified; write it again or answer in the conversation yourself |

With **Ask the customer**, the case goes to **Waiting for customer** when the question is sent. When the customer answers (text, photo or file, in any conversation of that customer), the answer is saved in **History**, the case goes back to **In progress** and the assignee is mentioned. This only happens after a question sent with **Ask the customer**; a case you put in **Wait for customer** by hand does not come back by itself.

If the account has reached its monthly AI cap, or the AI does not answer, your text goes out as you wrote it.

### 7. Let the AI open cases
When a customer reports a problem, makes a request or a complaint, or asks for something only a person can decide, the AI can open the case itself and give the customer its number. To set it up (administrators):

1. **Jev** must be on (AI agent → Jev, with the TypeSafe key). In the Jev card, the activity **Notice what only the team can solve** (group **Open cases for the team**) comes as **Deciding**. If it is **Observing** or paused, the AI does not open cases.
2. In **Case settings**, edit each type you want the AI to use and choose in **When the AI notices this kind of request**:
   - **The AI opens it and keeps helping the customer:** the case is opened, the AI says the number and keeps answering whatever else the customer asks, while the team works on the case.
   - **The AI opens it and hands the conversation to the team:** the case is opened, the AI says the number, leaves a private note with a summary and the conversation goes to the team. The AI stops answering it.
3. In **When is it this type?** describe, with your words, what goes in the type. Example: *A product arrived damaged or wrong, or stopped working under warranty.* The AI chooses between your types using the name and this text. Be specific: two types with similar descriptions confuse it.

What to expect:

- The AI only opens a case when it is at least 80% sure of the type. If not, it answers as usual.
- The case is born before the answer, so the answer can include its number. The title is the customer's first sentence and the description is the whole message. The case shows **Opened by the AI**.
- If the customer already has an active case of the same type, no second case is opened: the new message is added to that case as a note from the AI and the conversation is linked.
- The AI also tells the customer in what stage their open cases are, in plain words, without giving dates and without saying that something is solved.
- Safety net: if the AI says "I will check with the team" but no case was opened, Jev holds that answer and hands the conversation to the team.
- The assignee is notified (see "Who is notified"). If the case has no assignee, the owner of the customer's open deal is notified, or else the first administrator of the account.

### 8. Tell the customer automatically
Turn on **Tell the customer the case number and when it is resolved** in the type. The customer then receives, in the case conversation and in their language (Spanish, Portuguese or English; any other gets English):

| When | Message |
|---|---|
| Case opened | We logged your request as CAS-2026-0001. The team is already on it and we will let you know when it is resolved. (in Spanish: "Registramos tu solicitud con el número ...", in Portuguese: "Registramos sua solicitação com o número ...") |
| Case resolved | Your request CAS-2026-0001 has been resolved. If you need anything else, just write here. (in Spanish: "Tu solicitud ... fue resuelta ...", in Portuguese: "Sua solicitação ... foi resolvida ...") |

The opening notice is not sent for cases opened by the AI, because its own answer already gives the number. When a notice cannot go out, **History** says why:

| Message in History | Meaning |
|---|---|
| the case has no conversation | Link a conversation to the case |
| this inbox does not deliver messages | The inbox (API channel without a webhook) cannot send messages to the customer |
| outside the reply window of the channel | The channel's reply window has closed (official WhatsApp, after 24 h) |

### 9. Follow how cases are going
**Cases → Case metrics.** Choose **Last 7 days**, **Last 30 days** or **Last 90 days**. You see totals and the same numbers **By type** and **By assignee** ("Nobody" groups the unassigned).

| Column | What it counts |
|---|---|
| Opened | Cases opened in the period |
| By the AI | Of those, how many the AI opened |
| Resolved | Cases resolved in the period |
| Time to resolve | Average time from opening to resolving, in hours (the time waiting for the customer counts) |
| On time | Share of the resolved cases that were resolved by their due date (cases without a due date are left out; "—" when there is none) |
| Active now | Cases open, in progress or waiting for the customer today |
| Overdue now | Active cases past their due date today (in red) |

## Who is notified

| What happened | Who | How |
|---|---|---|
| A case is assigned to someone else (when opening or editing) | The new assignee | Private note in the case conversation mentioning them (it arrives in their notifications). Not sent if you assign it to yourself |
| The AI opened a case | The assignee, or the owner of the customer's open deal, or the first administrator | Same private note |
| The customer answered a question sent with **Ask the customer** | The assignee, or the deal owner, or the first administrator | Same private note |
| The AI could not send a reply written by the team | The person who wrote it (or the assignee, deal owner, first administrator) | Same private note |
| A case becomes overdue | Nobody is warned one by one | Red number in the menu and the **Risk radar** |

A case without a conversation does not notify anyone: it only appears under **Mine** and in the red number.

## When something fails or pauses

| What you see | What to do |
|---|---|
| "Fill in ... before resolving the case." / "Save the details before resolving the case." | Fill in the required details of the type and press **Save** on the case |
| "CAS-... is resolved: start not allowed" (or another status and action) | Someone changed the case in the meantime. Reload the page and check the status |
| "CAS-... has no conversation with the customer" | Link a conversation to the case before using **Reply through the assistant** |
| "This type has cases and cannot be deleted. Turn it off instead." | Edit the type and turn off **Available for new cases** |
| "Could not save. Try again." | Try again; if it repeats, check the values (a date, a number, an option of the list) |
| The reply stays in **waiting to be sent** | The conversation is in an inbox without a bot, or the workflow "CortexGen Caso" is stopped. Tell the installation administrator, or answer in the conversation |
| **could not be sent** | The AI could not post in the conversation. Check that the inbox is connected and write it again |
| The AI never opens a case | Check: **Cases** on for the account; Jev on, with the activity **Notice what only the team can solve** in **Deciding**; the type with the AI on and **Available for new cases** on; a persona answering that inbox |
| The AI opened a case of the wrong type | Improve **When is it this type?** and the name of the types |
| The customer did not get the notice | See the table in step 8 |
| The red number does not go away | It counts overdue active cases of the whole account; resolve or cancel them, or change their due date |

## Not included
- No page for the customer to follow the case: the customer only receives the two notices of step 8.
- Due dates in business hours: they count calendar hours.
- No automatic reminder or escalation when a case goes overdue (only the red number and the **Risk radar**).
- The AI does not fill in the details of the type; the team fills them in.
- No automatic distribution of cases by workload or rotation: the assignee is the default of the type or whoever you choose.
