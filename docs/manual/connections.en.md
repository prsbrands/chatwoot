# Connections: channels, WhatsApp by QR and the health of the AI bot

Connections puts all your channels in one list (WhatsApp by QR, official WhatsApp, Instagram, Messenger, website, email and others) and tells you, for each one, whether it is connected and who answers on it: the AI or your team. Find it in the menu, in the **Channels** section, as **Connections**. A red dot on its icon means something needs your attention.

*Also in: [Español](connections.es.md) · [Português](connections.pt.md)*

## Before you start

1. **Only administrators** see Connections. Agents do not see the screen or the red dot.
2. **The line about the AI bot** (who answers on each channel) needs **Bot Personas** turned on for your account (an administrator of the installation does this in the Super Admin). Without it, the screen still lists the channels and whether they are connected, but not the bot.
3. **To connect a WhatsApp number by QR** the account needs **WhatsApp Sessions** turned on in the Super Admin, and the installation needs its WhatsApp gateway set up (**Super Admin → Settings → WhatsApp Gateway**, with the gateway address and key). Use a **dedicated number** and have the phone with WhatsApp at hand to scan the code.
4. **To have the AI answer on a channel** you need a persona (menu **Personas**, AI agent section) and an agent bot (**Settings → Bots**).

## QR or official API?

| | WhatsApp by QR | WhatsApp official API (Meta) |
|---|---|---|
| How it connects | You scan a QR code with the phone, like linking a device in WhatsApp | Through Meta (WhatsApp Business "Quick setup with Meta" or WhatsApp Cloud), 360Dialog or Twilio |
| Where you manage it | **Settings → Integrations → WhatsApp Sessions** (also from the **WhatsApp by QR code** button) | In the inbox itself, **Settings → Inboxes** (also from the **WhatsApp official API** button) |
| What it has here | Outreach campaigns, appointment reminders and missed-appointment messages, the AI's follow-up when the customer goes quiet, and the alert when the session drops | The standard **Campaigns** menu. Outside the 24-hour window after the customer's last message, WhatsApp only allows approved templates, so the features on the left do not run on it |

In the list, the kind shows as "WhatsApp · QR code", "WhatsApp · Official API (Meta)" or "WhatsApp · 360dialog".

## Step by step

### 1. Read the screen
- At the top, a red line says how many channels need attention: "N channels need attention: customers there may be getting no answer."
- Channels are grouped in **WhatsApp** and **Other channels**, with the ones that need attention first.
- Each row shows the channel's name, its kind and phone number, a tag **Connected** or **Disconnected**, and a line about the bot (step 4). Click the name to open the inbox's settings.
- A **Fix** button appears on the rows that need attention (step 5).
- The **Disconnected** tag only exists for channels that can lose their connection: WhatsApp by QR, WhatsApp set up with Meta's quick setup, Instagram, Messenger, TikTok and email with Google or Microsoft. The others (website, Telegram, SMS and so on) always show Connected.

### 2. Connect a number by QR
1. In **Connections**, press **WhatsApp by QR code**. It opens **WhatsApp Sessions**.
2. Press **New session** and fill in:

| Field | What it is |
|---|---|
| Session name | 3 to 50 characters: lowercase letters, numbers and hyphens (for example `sales-line`) |
| Inbox | Leave "Create a new inbox for this session (recommended)". Pick an existing inbox only to reuse it: its connection is rewired to this session. If it finds an inbox that looks like the same number, it offers **Reuse this inbox** |
| Answer with an agent bot | Only appears if you have agent bots. Leave it on and pick the **Agent bot** so the AI answers on this number |

3. Press **Create**. The window **Pair WhatsApp** opens with a QR code ("Preparing QR code…" first).
4. On the phone, open WhatsApp → Settings → Linked devices → Link a device, and scan the code.
5. When you see "Number connected! The session is ready." press **Close**.
6. Go back to **Connections** and check the row: **Connected** and "AI answers as …" (step 4).

The session list shows **Session**, **Status**, **Phone**, **Inbox** and **Actions**:

| Status | Meaning |
|---|---|
| Created, Initializing | Starting up |
| Waiting for QR scan | Waiting for you to scan |
| Authenticating | The scan was accepted |
| Connected | Working |
| Disconnected | The session dropped (step 7) |
| Action required, Failed | The session needs help: press **Pair** again |

| Button | What it does |
|---|---|
| Pair | Shows the QR code to scan. Appears while the session is not Connected. It is also how you reconnect |
| Start | Starts a Disconnected session again |
| Stop | Stops a Connected session |
| Log out | Logs the number out of the session |
| Trash | Deletes the session (see step 7 before using it) |

### 3. Connect the official WhatsApp API
In **Connections**, press **WhatsApp official API**. It opens the creation of a WhatsApp inbox in **Settings → Inboxes**, where you choose the provider (WhatsApp Business, WhatsApp Cloud, Twilio or 360Dialog) and follow the screens. Meta's own steps are not covered here.

### 4. See whether the AI is answering
The line under each channel says who answers on it:

| What you read | Meaning |
|---|---|
| AI answers as … | All good: the bot is on and has a persona |
| No AI — your team answers | No bot on this channel. It is not a failure if that is what you want |
| Voice calls, answered by the voice agent | A voice number. The voice agent answers, not the text bot |
| The AI bot is on but has no persona, so it does not answer | **Problem** (red). The inbox calls the bot but there is no persona to answer |
| The AI bot's saved credentials are out of date, so it does not answer | **Problem** (red). The bot and the persona were saved with different credentials |
| A persona is set, but the AI bot is not on this channel, so it does not answer | **Problem** (red). The persona exists but the inbox does not call the bot |

Turning the bot on from the inbox's own settings does not set up the persona. Always do it from **Bot Personas → Channels**.

### 5. Fix a channel
**Fix** takes you where the problem is solved:
- **Bot problem:** to **Bot Personas → Channels**. In the channel's row choose the **Persona** and the **Agent bot**, turn **Bot active** on and press **Save**. Saving connects the bot to the inbox and writes its credentials again, which solves the three problems of step 4. The Save button only works with a persona and a bot chosen. If it says there are no agent bots, create one in **Settings → Bots**.
- **WhatsApp by QR that dropped:** to **WhatsApp Sessions** (step 7).
- **Another channel that dropped:** to the inbox's settings, where you reconnect it.

The trash in a row removes the persona's route from that channel.

### 6. The red dot in the menu
The red dot on the **Connections** icon appears when any channel is **Disconnected** or has one of the three bot problems. It is calculated when the page loads, so after fixing something reload the page or open Connections. Only administrators see it.

### 7. When a QR session drops
The system checks the sessions every 5 minutes. When a session is not Connected in two checks in a row (so it takes around 5 to 10 minutes to notice, to avoid false alarms when the gateway restarts), the inbox is marked:
- the red dot, and **Disconnected** on the row in Connections;
- a warning in the inbox's settings: "This WhatsApp number is disconnected. Replies and follow-ups are not delivered until you scan the QR code again on the same connection." with the button **Scan the QR code**;
- an email to the account administrators;
- the AI's follow-ups skip that inbox, and Outreach campaigns on that number pause (see the Outreach manual).

To reconnect:
1. Press **Fix** in Connections (or **Scan the QR code** in the inbox's settings). You land on **WhatsApp Sessions**.
2. On the session of that number press **Pair** and scan the QR code.
3. When it says "Number connected! The session is ready." the alert goes away at once.

**Always reconnect on the same session.** Creating a new session for the same number makes a duplicate inbox, without the old conversations and bot. If you do need a new session, **New session** offers **Reuse this inbox** when it finds the old one.

Deleting a session (trash, then **Delete**) removes the connection with the gateway but keeps the inbox and its conversations; the bot stops answering there. To bring it back, create a **New session** and reuse the old inbox.

## When something fails or pauses

| What you see | What it means and what to do |
|---|---|
| "OpenWA gateway is not configured. Set the gateway URL and API key in Super Admin → Settings → WhatsApp Gateway." | The installation has no gateway data yet. Ask its administrator |
| "Could not reach the OpenWA gateway" | The gateway did not answer. Try again in a minute; if it persists, tell the administrator of the installation |
| "Session name must be 3-50 characters, lowercase letters, numbers and hyphens only." | Fix the **Session name** |
| "The selected inbox must be an API channel inbox." | You picked an inbox that cannot be reused. Leave "Create a new inbox for this session" |
| "Session not found for this account." | That session belongs to another account or no longer exists. Reload the list |
| "Bot route not created: persona not found in the bot layer." | The automatic setup looks for a persona with a fixed name chosen by the installation, and your account has none with that name. The number connected but the bot will not answer: go to **Bot Personas → Channels** and set the persona, the bot and **Bot active** |
| "Bot route not created: Supabase env vars are missing. Add the route manually." or "Bot route creation failed. Add the route manually." | Same fix: **Bot Personas → Channels** |
| The QR code stays on "Preparing QR code…" | Wait a few seconds: it keeps checking by itself. If it does not show, close the window and press **Pair** again. If the status is Failed or Action required and it persists, tell the administrator of the installation |
| The row says Disconnected but the phone is fine | The gateway lost the session. Press **Pair** and scan again |
| "This inbox belongs to a Twilio voice route…" when saving a channel | That inbox is only the record of voice calls: the voice agent answers them. Do not attach a text bot to it |
| Messages arrive but the AI does not answer | Read the bot line in Connections (step 4) and apply **Fix** |
| A new number connected but the bot is silent | The bot line shows the problem. Do step 5 |

## Not included
- The screen does not connect Instagram, Messenger, website or email: they are created in **Settings → Inboxes**. Connections only shows and fixes them.
- QR sessions never reconnect by themselves: when WhatsApp drops the link, someone has to scan the code again.
- The red dot and the lines are not live: they update when the page loads.
- Agents do not get the alert; only administrators (on the screen and by email).
- No message history or metrics per channel on this screen.
- The status Connected does not prove that messages arrive for channels that cannot report a drop (website, Telegram, SMS).
