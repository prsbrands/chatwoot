# Outreach: campaigns on your WhatsApp QR number

Outreach sends one message to a list of people through your WhatsApp QR number, at a pace that protects the number from being banned. Find it in the menu under **CRM → Outreach**.

*Also in: [Español](outreach.es.md) · [Português](outreach.pt.md)*

## Before you start

1. **A connected WhatsApp QR number.** It must be a number connected by QR in **Connections** (not the official WhatsApp API). If the session is disconnected, campaigns pause by themselves.
2. **The time zone of the number.** Open the inbox of that number in Settings → Inboxes → Business hours and choose its time zone. Campaigns do not start on an inbox set to UTC, because the opening hours would be wrong.
3. **Outreach turned on** for your account (an administrator of the installation does this in the Super Admin). Only administrators of the account see and use Outreach.
4. **Age of the number.** A new number can send little: 20 messages a day for the first 3 days, 50 until day 7, 100 until day 14, 200 after that. The campaign never goes over this, even if you set higher limits.

## Step by step

### 1. Create the campaign
**Outreach → New campaign.** Give it a name, choose the number and write the first message. You adjust everything else on the campaign page, while it is still a **Draft**.

### 2. Write the message
- **Versions:** up to 3 texts. They take turns from one person to the next, so not everybody gets the same words. Use **Add another version**.
- **Variables:** `{name}` (first name), `{full_name}`, `{company}` and any column of your file, written without accents and in lowercase (the column "Ciudad" becomes `{ciudad}`). Anybody who does not have the data a version needs is left out of the campaign, so nobody gets "Hello {name}".
- **Random options:** `{Hi|Hello|Hey}` picks one of the words each time.
- **Bubbles:** a blank line starts a new WhatsApp message (up to 4). Between bubbles the number shows "typing…".
- **Cold list:** tick it when the people never talked to you. The campaign then uses only half of the number's daily limit.
- **Opt-out line:** text added at the end of every message, for example "Reply STOP to stop receiving messages." Whoever answers with a stop word is blocked and never receives a campaign again.

Press **Save**. If the campaign was ready, it goes back to Draft and you prepare the list again.

### 3. Set the pace
Everything here can only make the campaign slower than the number's own limits, never faster.

| Field | What it does | Default |
|---|---|---|
| Starts / Ends at (hour) | Sending window, in the time zone of the number | 8 to 20 |
| Days | Days of the week allowed | Mon to Sat |
| Gap between messages | A random number of seconds between the two values, never under 15 | 20 to 45 |
| Per hour, at most | Ceiling per hour for this campaign | 30 |
| Per day, at most | Ceiling per day for this campaign (blank: the limit of the number) | blank |
| Messages before a break | After this many messages the campaign rests | 10 |
| Break (min) | A random rest between the two values | 5 to 15 |

A campaign that reaches a limit does not fail: it waits and continues in the next window.

### 4. Set the list
Choose **Spreadsheet** or **CRM contacts** and press **Use this list**. Using another list replaces the previous one.

**Spreadsheet.** CSV, XLSX or ODS, up to 10,000 rows, with the column titles in the first row. (Older XLS files: save them as XLSX first.)
- Choose the file. The first rows are shown.
- Say which column is the **phone** (required), the **name** and the **company**. Outreach guesses them from the titles.
- **Country code:** added to numbers written without one (507 by default). A number with "+" or "00" is used as it is. A long number without the country code is rejected instead of guessed.
- All other columns can be used as variables in the message.
- People in the file do not become contacts until they answer. A cold list does not fill your CRM.

**CRM contacts.** Pick a label and/or an inbox. Contacts with no phone number are shown as left out.

### 5. Review and start
1. **Send a test to yourself:** type your number and press **Send test**. You receive the first version, with the data of the first person on the list. It does not count in the campaign.
2. **Prepare the list.** Outreach checks everybody and shows how many **will receive the message** and how many are **left out and why** (see the table below).
3. **Start sending.** The campaign starts right away.

### 6. Follow it, pause it, cancel it
On the campaign page:
- **Pause** stops after the message being sent. **Resume** continues.
- **Cancel campaign** stops for good; people still waiting are cancelled.
- Results update on their own: **Sent**, **Replied**, **Waiting**, **Failed**, **Asked to stop** and **Left out**, with the list of people and a filter by status.
- Reply rate counts people who answered, out of those who received the message. A reply only counts for the campaign for 72 hours after the message.

## Who is left out (and why)
The check runs when you prepare the list **and again right before each message**, because someone may have asked to stop in between.

| Reason | Meaning |
|---|---|
| Asked to stop receiving messages | The contact is blocked |
| In the exclusion list | Added in Outreach → Exclusion list |
| No phone number / Not in a valid format | The number cannot be used |
| Same number as another person on the list | Only the first one receives |
| Already waiting in another campaign | One campaign at a time per person |
| Received a campaign in the last 30 days | Avoids pestering |
| Open conversation with your team | Campaigns never interrupt a conversation in progress |
| Missing data the message uses | For example, `{name}` for someone without a name |

## Exclusion list
**Outreach → Exclusion list.** Numbers that no campaign will ever touch (your accountant, a competitor, a client you only call). Paste numbers, one per line or separated by commas. This is different from someone asking to stop: people in this list **are still answered normally** if they write to you.

## What happens when someone answers
The answer arrives in your inbox like any other message, and the number's bot answers as usual. The campaign marks the person as **Replied**. If the person had never written to you, the conversation only appears in your inbox when they answer; before that, there is nothing in the Conversations list.

## When a campaign pauses by itself
The menu shows a red number and the campaign explains why:
- **The WhatsApp session of the number is disconnected:** reconnect the number in Connections, then press **Resume**.
- **Three sends in a row failed:** check the number and the connection, then **Resume**. People whose send failed are not sent again automatically.
- **The number has no WhatsApp session:** the connection was removed; reconnect it.

If **Start sending** says the inbox needs a time zone, set it as explained at the top. If it says nobody is waiting to receive, prepare the list again.

## Good practice to protect your number
- Start small with a new number and let the age limits work.
- Prefer people who already know you. For cold lists, tick **Cold list**, write a short message that says who you are and use the opt-out line.
- Use 2 or 3 versions of the text and random options, and avoid links in the first message.
- Keep the default gaps and breaks. Do not run several large campaigns on the same number on the same day.
- Look at **Asked to stop** and **Failed**. Many of either means the list or the message needs work.

## Not included
- No "delivered" or "read" marks (WhatsApp by QR does not report them).
- One number per campaign, no rotation between numbers.
- No campaigns on the official WhatsApp API or SMS here; the standard **Campaigns** menu keeps those.
- No automatic follow-up for people who did not answer.
