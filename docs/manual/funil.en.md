# Sales pipeline, Risk radar and Tasks: from the first message to the closed deal

These three screens work together. The **Pipeline** shows every deal on a board, stage by stage. The **Risk radar** lists the deals that went quiet and can die without an answer. **Tasks** keeps what was agreed, with a due date. In the menu: **Risk radar** is near the top, **Pipeline** and **Tasks** are in the **CRM** section. Inside each conversation, the **Deal** card in the side panel shows the customer's deal.

*Also in: [Español](funil.es.md) · [Português](funil.pt.md)*

## Before you start

1. **Sales Pipeline turned on** for your account (an administrator of the installation does this in the Super Admin, in the account's features). Without it, the three screens and the **Deal** card do not appear.
2. **Who can do what.** Administrators and agents see and use the Pipeline, the Risk radar and Tasks, move deals, and create tasks. Only administrators create pipelines and change stages (the buttons **Pipeline settings** and **New pipeline** do not appear for agents). A task can be deleted by whoever created it or by an administrator.
3. **Deals appear by themselves.** When a contact writes for the first time in an inbox where the AI bot is active, a deal opens for them in the first open stage of the default pipeline. A contact has one open deal at a time. You can also press **Create deal** in the **Deal** card of a conversation. (If the bot is not active in the inbox, check **Connections**: the deal is not created.)
4. **For the AI to move deals and give scores** you need Jev turned on (see step 5).
5. **For the "Bot follows up" group of the radar** you need follow-up turned on in the persona of that inbox (**Follow up after N hours of silence**, under Bot Personas).

## Step by step

### 1. Read the pipeline
**CRM → Pipeline.** Each column is a stage. At the top of the column you see how many deals it holds and their total value. The deals of a column go from the most recently moved to the oldest.

Each card shows:
- the title (the contact's name or phone), the contact's name when it differs, the value, and how long it has been in the stage;
- a **colored dot** when the deal is at risk: amber is "Going cold", red is "Critical" (hover to read it and how long since the last interaction);
- a **number badge**, the score from 0 to 100 (hover for Hot, Warm or Cold);
- an amber box when Jev has a suggestion (step 5);
- the link **Open conversation**.

At the top: the **pipeline selector** (the choice stays in the link), the **Only at risk** button (shows only the deals going cold or critical, and turns dragging off while it is on) and, for administrators, **Pipeline settings** and **New pipeline**.

### 2. Move a deal
Drag the card to another column. You see "Deal moved to" followed by the stage's name.
- Dragging to a **Lost** stage asks "Why was this deal lost?". Write the reason and press **Mark as lost**. If you cancel, the card goes back.
- Dragging to **Won** asks nothing.
- To reopen a deal, drag it back to an open stage.
- Every move goes into the deal's history: who moved it (a person, "The AI" or the system) and, for lost deals, the reason.

### 3. Use the Deal card inside the conversation
In the side panel of the conversation, open **Deal**. If the contact has no deal you see "No deal for this contact yet." and **Create deal**. If it has, you see (the open deal, or the most recent one):

| Part | What it does |
|---|---|
| Pipeline | Appears when the account has more than one pipeline. Choosing another moves the deal to the first open stage of that pipeline |
| Stage | Moves the deal. Choosing a Lost stage asks for the reason |
| Value | The value in the deal's currency (whole units). Saved when you leave the field. New deals use USD, or BRL in accounts in Portuguese |
| Risk and score | The state ("On track", "Going cold" or "Critical"), how long since the last interaction, how long the stage tolerates, and the score with the factors that built it |
| History | The last 5 moves, with the reason |
| Next steps | The pending tasks and the upcoming appointments of the deal. Buttons **Task** and **Appointment**. Without any, it warns "No next step yet. Add a task so this deal does not go quiet." |
| Open pipeline | Takes you to the board |

If Jev has a suggestion, an amber box shows "Jev suggests moving to … (NN%)" with **Accept** and **Dismiss**.

### 4. Set up pipelines and stages (administrators)
**Pipeline → New pipeline** creates a pipeline with the template stages in the account's language (in English: New lead, Contacted, Qualifying, Proposal sent, Negotiating, Won, Lost). You can rename or delete them. **Pipeline → Pipeline settings** opens the stages window:

| Field | What it does |
|---|---|
| Pipeline name | Renames the pipeline |
| Make default | The default pipeline receives the deals that open by themselves. Only one is the default |
| Delete pipeline | Only a pipeline that is empty and not the default can be deleted |
| Name | The stage's name |
| Expected hours | How long a deal can sit in the stage before it counts as cold. Empty means 24 |
| Needs a person | When the AI moves a deal into this stage, the conversation opens for your team, with a note |
| Arrows (Move up, Move down) | Change the order |
| Trash (Delete stage) | Only for open stages with no deals. A stage with deals cannot be deleted: move them first |
| Add stage | Creates a stage before Won and Lost |

Each field saves by itself when you leave it. **Done** closes the window. Every pipeline has exactly one **Won** and one **Lost** stage; they cannot be added or deleted.

### 5. Let Jev move the deals
Open **Jev** in the menu (AI agent section). Turn Jev on if it is off (save the TypeSafe key and press **Turn Jev on**). In the group **Sales pipeline**, the activity **Move the deal along the pipeline** starts as **Observing**: it only counts what it would do. To let it act, press **Let Jev decide**; you can go back to observing at any time.

How it decides (it reads each customer message, once per burst of messages):

| Jev's confidence | What happens |
|---|---|
| 80% or more | Moves the deal by itself. The history says "The AI moved it to …" with the percentage as the reason |
| Between 50% and 80% | Leaves a suggestion on the card, with **Accept** and **Dismiss** |
| The customer clearly bought ("Won") | Always a suggestion, at any confidence from 50% |
| A person moved the deal in the last 24 hours | Only suggests |

- It only moves **forward**, never back, and **never to Lost**: the AI does not know the reason.
- It only picks among the stages that came with the template (the first five, from New lead to Negotiating). Stages you add yourself are only reached by hand.
- Any move by a person clears a pending suggestion.
- If the AI moves a deal into a stage marked **Needs a person**, the conversation opens for your team with a note ("The deal reached … which needs a person. The conversation was opened for the team.").

### 6. Understand risk and score
**Risk.** Every 5 minutes the Pipeline recalculates how long each open deal has gone without a real interaction: a public message to or from the customer, in any conversation of the contact. Private notes and system messages do not count.

| State | When | Example with a stage of 24 expected hours |
|---|---|---|
| On track | Less time than the stage's **Expected hours** | Under 24 h |
| Going cold | The Expected hours or more | From 24 h |
| Critical | 3 times the Expected hours or more | From 72 h |

**Score.** A number from 0 to 100 made by a formula, never by guess, and always shown with its factors. It starts at 30 and adds or subtracts:

| Factor | Points |
|---|---|
| Agreed to a next step; asked for a price or proposal; wants to buy or start | +12 each (up to 3) |
| Price objection; not the right moment; comparing or in doubt | −8 each (up to 3) |
| Described the need; mentioned a budget; mentioned a timeline; decides or named who decides | +5 each (up to 4) |
| Recent interaction / going cold / no interaction for a long time | +10 / −10 / −20 |

The score is **Hot** from 70, **Warm** from 40 and **Cold** below 40. Until Jev finds at least two signals in the conversation there is no score ("No score yet: Jev needs at least two signals from the conversation."). The signals come from Jev, so it needs the activity of step 5 to be Observing or Deciding.

### 7. Work the Risk radar
Open **Risk radar** in the menu. It lists the open deals that are going cold or critical, the most urgent first. At the top, small tags count each group.

| Group | Meaning |
|---|---|
| Critical | Quiet for 3 times the stage's expected time or more |
| Going cold | Quiet for more than the stage's expected time |
| Bot follows up | Would be cold, but the AI is going to resume the conversation by itself |

"Bot follows up" appears when: the persona of the inbox has follow-up turned on, the conversation is on a WhatsApp number connected by QR that is connected, it is still with the bot (no person assigned), the bot spoke last, the customer wrote in the last 7 days, follow-ups for that silence are not used up, and the inbox time zone is not UTC.

Each row shows: the group, the deal and its value, the pipeline and stage, "Quiet …", the score, who has it, and the follow-up.
- **Who has it:** "With …" (the person assigned to the conversation), "With the AI (…)" or "No owner".
- **Follow-up:** "The AI follows up …" with the expected time, "The AI follows up soon" (the time passed and it waits for the sending window of 8:00 to 20:00 or the number's daily limit), or "No follow-up scheduled".
- Click the row to open the conversation (or the Pipeline, if the deal has none).
- **Take over** assigns the conversation to you and opens it, and the AI stops answering. You see "The conversation is yours now: the AI stopped answering it." The button does not appear when a person already has it.

Above the list there can be blocks that need action:
- A block that says "N appointments already happened — did the customers show up?": press **Mark as done** or **Did not show up** for each one.
- A block that says "N open deals have no next step": deals with no pending task and no upcoming appointment, in the deal or in the contact. Click one to open it and add what comes next. This is the one number that should be zero. The oldest in their stage come first, up to 50.
- A block that says "N cases are past their due date", when the account uses Cases.

When there is nothing at risk you see "No deal at risk. Every open deal had an interaction within its stage's time."

### 8. Keep what was agreed in Tasks
**CRM → Tasks.** Press **New task** and fill in:

| Field | What it is |
|---|---|
| What needs to be done | The title. Required |
| Due | Date and time. Optional |
| Who does it | A person, or "Nobody". Starts as you |
| Notes | Up to 2,000 characters |

Press **Save**. A task made here is not tied to any deal. To tie a task to a deal, press **Task** in the **Deal** card of the conversation.
- The buttons **To do** and **Done** choose which list you see, and **Mine** and **Everyone's** whose tasks. The To do list is grouped as **Overdue**, **Today**, **Upcoming** and **No due date**. The Done list shows the last 100.
- The circle at the left of a task marks it as done (**Mark as done**) or reopens it (**Reopen**). The pencil edits and the trash deletes; they appear when you hover over the task.
- The due date turns red when it passes. The task's link opens its deal's conversation, or the contact.

## When something fails or pauses

| What you see | What it means and what to do |
|---|---|
| Pipeline, Risk radar, Tasks or the Deal card do not appear | Sales Pipeline is not turned on for the account. Ask the administrator of the installation |
| A customer wrote and no deal appeared | The inbox has no active AI bot (check **Connections**), the contact is blocked, or the contact already has an open deal (search for it on the board). You can press **Create deal** in the conversation |
| "Could not update the pipeline" | The change was not saved. The board reloads; try again |
| "Only an empty pipeline that is not the default can be deleted. Move its deals or pick another default first." | Move its deals to another pipeline, or press **Make default** on another pipeline first |
| A stage will not delete | It has deals. Move them to another stage first |
| A card jumps back after you drop it on a Lost stage | You cancelled the reason window. Drop it again and write the reason |
| Jev does not move deals | Check: Jev is on and **Move the deal along the pipeline** says **Deciding**; the target is a template stage and ahead of the current one; a person did not move the deal in the last 24 hours (then it only suggests); the confidence reached 80% |
| "No score yet: Jev needs at least two signals from the conversation." | Normal at the start. It appears when the customer gives more information |
| "Could not take over the conversation. Try again." | The assignment failed. Try again, or open the conversation and assign it to yourself |
| A radar row says "No follow-up scheduled" | The AI will not resume that conversation: see the conditions of "Bot follows up" in step 7. Take over or write to the customer yourself |
| The delete button of a task shows an error | Only whoever created the task or an administrator can delete it |
| The Risk radar is empty | Good: no open deal has gone past its stage's expected time |

## Not included
- No "New deal" button on the board: deals are born from conversations. And no way to delete a deal from the screen.
- Jev never moves a deal to Lost or backward, and never to stages you add yourself.
- Nobody is notified of tasks that are due, of Jev suggestions or of radar changes: you have to look at the screens.
- No forecast or revenue reports on these screens.
- One open deal per contact. Deleting a contact deletes their deals and tasks; merging two contacts moves them to the contact that stays.
- The total at the top of a column adds the values as they are and shows them in the currency of its first deal; it does not convert currencies.
