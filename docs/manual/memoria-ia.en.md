# AI memory: what the AI remembers about each customer

AI memory is a short summary and a list of facts about each customer that the AI keeps up to date by itself after the conversations, and reads before answering, in any channel. You can read it, correct it and add to it. Find it in the **AI memory** block of the right-hand panel of any conversation, and in the **AI memory** tab of the contact (Contacts → open a contact).

*Also in: [Español](memoria-ia.es.md) · [Português](memoria-ia.pt.md)*

## Before you start

1. **There is no switch to turn on.** The panel is part of the installation and is there for every account. The AI only fills it in for customers who talked through an inbox answered by an AI bot.
2. **Who can use it.** Agents and administrators see and edit the memory of any customer.
3. **An AI answering the inbox.** A persona must answer at least one inbox (AI agent → Personas, tab **Channels**). The installation administrator must also keep the n8n workflow "CortexGen Memória" published: it is what writes the memory.
4. **When the AI writes.** A conversation is read when the customer's last message is at least 30 minutes old (so the memory shows up some 30 to 40 minutes after the end of a conversation, a bit more if many customers are waiting), the conversation had activity in the last 7 days and has customer messages not read before. Several conversations of the same customer are read one at a time, and only the new part is read.
5. **Cost.** The AI uses the persona's light model (or the persona's normal model if it has none). It counts in **AI usage**, as **Customer memory**, and in the account's monthly AI cap. An account that has reached the cap is skipped, and its memory stops updating until the next month or until the cap is raised.
6. **Numbers to know.**

| What | Value |
|---|---|
| Workflow runs | every 10 minutes |
| Customers updated per run | up to 5 |
| Messages read per round | up to 40 new ones, plus 6 earlier ones for context |
| Summary | up to 1,500 characters (the AI writes up to 5 sentences) |
| Each fact | up to 300 characters (the AI writes them short, up to about 15 words) |
| New facts per round | up to 10 |
| Facts per customer | when the total passes 30 (yours included), the AI drops its own oldest facts that are not pinned |
| What the AI reads before answering | the summary and the facts, up to 1,500 characters in total |
| Retry after a failed round | after 1 hour |

## Step by step

### 1. Open a customer's memory
- **In a conversation:** in the right-hand panel, open the **AI memory** block (by default it comes right after the deal block; the arrow opens and closes it).
- **In a contact:** Contacts → open the contact → tab **AI memory**.

The memory belongs to the contact and is the same in every channel. If the same person is two different contacts (for example a WhatsApp number and an email), each has its own memory until you merge the contacts.

If nothing was written yet, the panel says "Nothing remembered yet. The AI fills this in when a conversation has been quiet for 30 minutes, and reads it before answering in any channel."

### 2. Read it
- **Summary:** where things stand now, in a few sentences: what the customer is asking for at the moment, what was agreed, what is pending. Under it, "Updated by the AI on ..." gives the date of the last update by the AI.
- **Facts:** one short line each about what stays true about the customer: who they are, their business, budget, decisions, objections, preferences (schedule, channel, tone), what they bought, and commitments with a date or an owner. A fact marked **team** was written or corrected by a person. A pin in color marks a pinned fact. Pinned facts come first, then the oldest ones.

### 3. Add a fact
Type it in the field **Add a fact about this customer** and press Enter, or press the **+** button (**Add fact**). A fact you write is marked **team**.

### 4. Correct or delete a fact
Hover over the fact:

- The pencil (**Edit fact**) lets you rewrite it; press Enter or **Save** (**Cancel** gives up). A fact you edit becomes **team**.
- The trash can (**Delete fact**) deletes it right away, without asking for confirmation.

### 5. Pin a fact
Press the pin next to the fact (**Pin: the AI reads it first and never changes it**). To undo, press it again (**Unpin**). Use it for what must never be forgotten or changed, such as "do not call before 6 p.m.".

### 6. Edit the summary
Press the pencil **Edit summary**, rewrite it (up to 1,500 characters) and press **Save** (or **Cancel**). The AI receives your text on the next round and keeps what is still true, but the summary is not locked: the AI can rewrite it later. For something that must stay, use a pinned fact.

### 7. What the AI can and cannot change

| Item | Written by | Can the AI change or delete it? |
|---|---|---|
| Fact without a tag, not pinned | The AI | Yes: it changes it when the customer corrects it and deletes it when it is no longer true or the summary now covers it |
| Fact marked **team** | A person (written or edited) | No |
| Pinned fact | The AI or a person | No: the AI reads it first and never changes it |
| Summary | The AI | It updates it every round; if you edit it, it keeps your text but can rewrite it later |

### 8. How the AI uses the memory
Before each answer, the AI receives a section "CUSTOMER MEMORY" with the summary and the facts: pinned facts first, then the newest ones, up to 1,500 characters in total (a long summary leaves less room for facts, so keep it short). The AI uses it so as not to ask again what the customer already said and to continue where things stand. What the customer writes now always wins over the memory, and the AI never says that it keeps notes about the customer. If the memory cannot be read, the AI simply answers without it.

## What the AI writes and what it never writes
- **It writes** what the customer said, decided or promised: who they are, their business, budget, decisions, objections, preferences, what they bought, personal context they shared, and open commitments with a date or an owner (removed when fulfilled).
- **It does not write** what the business or the AI did or said (that a price, a quote or a link was sent, who handled it, what the team answered), greetings and small talk, the business's own prices and rules, guesses, momentary states ("is online now"), card numbers, passwords or documents.
- **Each piece of information goes in one place only:** what is only the current request or status goes in the summary; what stays true goes in a fact. A fact the summary now covers is removed, and a fact already in the memory in other words is not added again.

## Merged and deleted contacts
- **Merge** (Contacts → open a contact → tab **Merge**): the facts of both contacts stay with the contact that remains, the two summaries are put one after the other, and the AI rereads the conversations to fill in what is missing.
- **Deleting a contact** deletes its memory.

## When something fails or looks wrong

| What you see | What to do |
|---|---|
| "Nothing remembered yet ..." | Normal for a new customer. Wait until the conversation has been quiet for 30 minutes. If it never fills in: the inbox has no AI answering it, the conversation is older than 7 days, the account is at the monthly AI cap, or the workflow "CortexGen Memória" is stopped (ask the installation administrator) |
| The memory does not update | Same checks; also remember that only new messages from the customer start a new round |
| "Could not save the AI memory. Try again." | Try again; a fact can have up to 300 characters and the summary up to 1,500 |
| The AI asks again what the customer already said | Add the fact yourself and pin it |
| A wrong fact | Edit it (it becomes **team**, and the AI does not touch it again) or delete it |
| A fact that is only an action of the company, or repeats the summary | Delete it; the AI should avoid this since the last adjustment, and tell the installation administrator if it keeps happening |
| The memory looks too long | Keep the summary short: summary and facts together go to the AI only up to 1,500 characters, and what exceeds is left out |

## Not included
- No memory for customers who never talked through an inbox with an AI bot.
- No view of all memories at once or search by memory: it is one customer at a time.
- No history of the changes (who changed which fact); only the current state.
- No confirmation before deleting a fact, and no way to bring it back.
- The AI does not store documents, passwords or card numbers.
