# AI evolution: the AI learns from what your team answers

Once a day, the AI reads the conversations it could not handle on its own and what your team answered, and proposes concrete changes to its knowledge base and its instructions. Nothing changes until you apply it. Find it in the menu under **AI agent → AI evolution**.

*Also in: [Español](evolucao-ia.es.md) · [Português](evolucao-ia.pt.md)*

## Before you start

1. **AI Evolution turned on** for your account (an administrator of the installation does this in the Super Admin, in the account's features, switch **AI Evolution**). Without it the menu item does not appear.
2. **Only administrators** of the account see and use AI evolution, because applying a proposal changes the knowledge base and the instructions the AI uses with every customer.
3. **An AI answering your inboxes.** A persona must answer at least one inbox (AI agent → Personas, tabs **Personas** and **Channels**). The proposals go to the knowledge base and the instructions of that persona.
4. **Something to learn from.** The AI only reads conversations that have at least one of these signals:

| Signal | What it is | What it teaches |
|---|---|---|
| Handed to the team, and a person answered | The AI handed the conversation to the team (the private note "Handoff · ...") and, afterwards, a person on the team wrote to the customer | The answer the AI did not know |
| Reply held by Jev | The same handoff note, with the draft that Jev held back (needs Jev's **Check before sending** on) | What the AI was about to say wrong and what the team sent instead |
| Case opened by the AI | A case the AI opened (needs **Cases** on) that the team answered through the assistant or resolved with a note in **What was done** | What the AI could not solve by itself |

5. **When it runs.** The round runs once a day, at 3:00 a.m. Panama time. New proposals appear after it. Only conversations quiet for at least 2 hours, with activity in the last 14 days, are read, and only the part not read before: the same stretch is never paid for twice.
6. **Cost.** The round uses the persona's normal model (not the light one) and counts in **AI usage** and in the account's monthly AI cap. An account that has reached the cap is skipped.
7. **Privacy.** Emails and phone numbers are removed from the text before it goes to the AI model.
8. **Numbers to know.**

| What | Value |
|---|---|
| Conversations read per account per day | up to 20 |
| Calls to the AI per day | one per persona, with all its conversations together |
| Proposals saved per call | up to 10 |
| Title / text of a proposal | up to 120 / 2,000 characters |
| Evidence kept on a proposal | the 10 most recent conversations (the chip counts all of them) |
| A rejected proposal is not proposed again | for 90 days |
| Proposals listed per tab | up to 200 |
| Progress | the last 12 weeks |

## Step by step

### 1. Open the proposals
**AI agent → AI evolution**, tab **Proposals**. A number on the menu item shows how many proposals wait for review (refreshed every minute).

- **To review / Applied / Rejected** choose the group. The ones to review come with the most evidence first.
- **All / New knowledge / Knowledge fix / Instruction** filter by kind.
- When there is nothing, the screen says "Nothing to review. Proposals appear after the daily round, when the AI handed a conversation to the team and the team answered."

### 2. Read a proposal
Each card shows:

- The **kind**, **where** it would go and a chip with the number of conversations that taught it ("3 conversations"). **edited** appears if someone changed the text.
- **Why:** one sentence with the reason.
- The **evidence**: for each conversation, **Customer:** what the customer said, **Team:** what your team answered, and the link **Open conversation #id**.

| Kind | What it does | Where it goes |
|---|---|---|
| New knowledge | Adds a short section with a fact the team gave (a price, a deadline, a policy, an area served) | The knowledge document the AI suggests, or the document **Aprendizados da IA** when none fits |
| Knowledge fix | Replaces a sentence of the knowledge base that the team contradicted or completed. The card shows the text to replace, crossed out, under **Replaces this text of the knowledge base** | The document where that text is |
| Instruction | One sentence about how the AI should behave (for example, not to promise a delivery date). It is never a fact or a price | The instructions of the persona |

The AI proposes only what your team said or did, never a price, date or policy of its own. If five customers asked the same thing, you see one proposal with five conversations as evidence, not five proposals.

### 3. Edit and apply
Before applying you can change the text:

- **Title** (not shown for Instruction).
- **Text for the knowledge base** (New knowledge and Knowledge fix) or **Instruction for the AI** (up to 2,000 characters).

Press **Apply**. The message "Applied" confirms, and the proposal moves to **Applied**, with who applied it and the date. The AI uses the change from the next message on; no deployment is needed. What happens in each kind:

- **New knowledge:** a section `### Title` followed by the text is added at the end of the document. In **Aprendizados da IA** (a document created by the system, with this name in any language, linked to the persona the first time), you find these sections in AI agent → Personas → **Knowledge base**.
- **Knowledge fix:** the text shown crossed out is replaced by the new text.
- **Instruction:** a line `- instruction` is added at the end of the persona's instructions, under a heading `## Aprendizados` (created the first time).

### 4. Reject
Press **Reject**, write why in the field "Why not? The AI will not propose it again." (optional but useful) and press **Reject** again. **Cancel** gives up. The proposal goes to **Rejected** with your reason, and the AI is told not to propose it again for 90 days.

### 5. Undo
In **Applied**, **Undo** puts the knowledge base or the instructions back as they were before, and the proposal returns to **To review** ("Undone: back to review"). It only works if nobody edited that text after the proposal was applied; otherwise it refuses, so it never erases someone else's edit.

### 6. Follow the progress
Tab **Progress**: the last 12 weeks, newest first, for the conversations on inboxes with the AI.

| Column | What it counts |
|---|---|
| Week of | The Monday of the week |
| Conversations | Conversations in which the customer wrote |
| Handed to the team | Percentage of those handed to the team, with a bar |
| Replies held by Jev | Replies Jev held back before sending |
| Cases opened by the AI | Cases the AI opened |
| Proposals applied | Proposals you applied that week (highlighted when above zero) |

It shows the trend next to the changes you applied; it does not prove that a change caused an improvement.

## When something fails or pauses

| What you see | What to do |
|---|---|
| "Nothing to review ..." for days | Check: **AI Evolution** on; a persona answering an inbox; conversations that were handed to the team and answered by a person (and quiet for 2 hours); the account is not at its monthly AI cap; the daily round is running (ask the installation administrator) |
| "the text to replace is no longer in the knowledge base" | Someone edited the knowledge base. Change it by hand in AI agent → Personas → **Knowledge base**, then **Reject** the proposal |
| "the knowledge document no longer exists" / "the persona no longer exists" | The document or persona was deleted; **Reject** the proposal |
| "the text changed since it was applied; undo it by hand" | The text was edited after you applied it; fix it by hand in Personas |
| "only pending suggestions can be applied" | Someone else already decided it; reload the page |
| "Could not save. Try again." | Try again; check that the title and text are filled in and within the limits |
| A proposal says "in "Aprendizados da IA"" | It is the shared document for new knowledge; it is not in your language because the system creates it |

## Good practice
- Read the evidence before applying: one odd conversation is not a policy. Prefer proposals with several conversations.
- Edit the text to your voice and remove anything specific to one customer.
- Reject with a short reason; it teaches the AI what you do not want.
- After applying, watch **Progress** over the next weeks.

## Not included
- It does not apply anything by itself: every change needs your **Apply**.
- It does not learn from edits your team makes to the AI's replies, only from what the team answers when the AI hands over, from held replies and from cases.
- A rejected proposal cannot be reopened (only applied ones can be undone).
- There is no filter by persona on the screen.
- It does not judge whether an applied change improved things; **Progress** shows the trend.
