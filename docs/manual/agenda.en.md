# Agenda: appointments, working hours, Google Calendar and AI booking

The Agenda is the calendar where your team books appointments with customers and sees who attends each one. It can share them with Google Calendar, and the AI can book on its own in the chat. Find it in the menu, near the top, as **Agenda**. Appointment types and working hours are in **Agenda settings** (the gear icon at the top right of the Agenda page).

*Also in: [Español](agenda.es.md) · [Português](agenda.pt.md)*

## Before you start

1. **Nothing to turn on.** The Agenda is on for every account (there is no switch in the Super Admin). Administrators and agents both see it.
2. **Time zones.** The grid uses the time zone of your browser. Each person's **working hours** have their own time zone (for example America/Bogota). The times the AI offers to customers, and the date and time in reminders, use the time zone of the person who attends.
3. **Google Calendar is optional**, and it needs the administrator of the installation to add the Google OAuth client once, in **Super Admin → Settings → Google Calendar** (fields "Google Calendar client ID" and "Google Calendar client secret"; the address to authorize at Google is `<your address>/google_calendar/callback`). This is not the "Google" screen used for Gmail and login. Until it is done, the Google card does not appear on the Agenda page. After that, each person connects their own Google account.
4. **To let the AI book appointments** more is needed: see step 8.
5. **Who can do what:**

| Action | Administrator | Agent |
|---|---|---|
| See the whole team's agenda, book and edit appointments, change their status | Yes | Yes |
| Delete an appointment | Any | Only the ones they created or attend |
| Create, edit and delete appointment types | Yes | No (they see the list) |
| Edit working hours | Anyone's | Their own |
| Connect Google Calendar | Their own | Their own |

## Step by step

### 1. Read the Agenda
- **Day** and **Week** switch the view. The week starts on Monday. The arrows move back and forward, **Today** comes back to now, and the title shows the period.
- The selector at the top right chooses whose appointments you see: **My agenda**, **Whole team** or one person.
- Each appointment is a block with its title, time and the customer's name (and who attends, when you are not looking at **My agenda**). Appointments that overlap share the width.
- Gray **Busy** blocks are times that person already has busy in Google Calendar, and **Busy all day** appears at the top of the day. They only show for people with Google connected.
- The red line is the current time.

### 2. Book an appointment
Three ways: click an empty time in the grid (it rounds to the half hour); press **New appointment** (starts at the next half hour); or, in a conversation of an account with Sales Pipeline, open the **Deal** card and press **Appointment**, which fills in the customer and the deal.

| Field | What it is |
|---|---|
| What | The title. Required. For example "Demo call, visit, consultation…" |
| Type | One of your appointment types, or "No type". Only appears if you created types |
| When | Date and time. Required |
| How long | 15, 30, 45, 60, 90 or 120 minutes |
| Free times that day | Appears after you pick a type. Click a time to fill in **When** |
| Who attends | The person who will be there. Starts as you |
| Who is being attended | The customer. Search by name, phone or email (from 2 letters). The × removes it |
| Where | Address, video call link or phone |
| Notes | Up to 2,000 characters |

Press **Save** (it is enabled once **What** and **When** are filled in).
- Picking a **Type** fills in how long, where (if empty) and, for new appointments, who attends by default.
- **Free times that day** shows the free times of that type for the person who attends on the day in **When**. You can always set the time by hand: booking by hand does not check overlaps.
- A type that **Needs confirmation** creates the appointment as **Waiting for confirmation**. Otherwise it is **Confirmed**.
- When the type creates a Google Meet link and Google has synced the appointment, opening it shows **Join the Google Meet**.

### 3. Follow each appointment to the end
Click an appointment. At the top you see its status and the buttons for the other statuses, plus **Delete**.

| Status | Button to set it | How it looks |
|---|---|---|
| Waiting for confirmation | (the starting state of types that need it) | Dashed amber |
| Confirmed | **Confirm** | Blue |
| Done | **Mark as done** | Teal |
| Did not show up | **Did not show up** | Red, crossed out |
| Cancelled | **Cancel** | Gray, crossed out |

- Waiting and Confirmed appointments take up the person's time: no free time is offered over them. The others free the time.
- Reminders are only sent for **Confirmed** appointments.
- If the account has Sales Pipeline, the **Risk radar** lists the appointments that ended in the last 30 days without an outcome, with the buttons **Mark as done** and **Did not show up**. Use them: they also feed the missed-appointment message (step 7).

### 4. Create the appointment types
**Agenda settings → Appointment types → New type** (administrators). The pencil edits a type and the trash deletes it (appointments already booked stay, without a type). Each type shows its duration, who attends by default and tags such as "Needs confirmation", "The AI books this type" or "Not offered".

| Field | What it does | Limits and default |
|---|---|---|
| Name | The name people pick. Required | |
| Duration (min) | How long it lasts | 5 to 1,440. Default 60 |
| Gap before (min), Gap after (min) | Free room kept around each appointment | 0 to 240. Default 0 |
| Minimum notice (min) | How soon from now it can be booked | 0 to 43,200. Default 120 |
| Bookable up to (days ahead) | How far ahead it can be booked | 1 to 365. Default 60 |
| Who attends by default | The person whose agenda is used for free times. "Whoever books" leaves it open | |
| Where | Address, video call link or phone | |
| Needs confirmation | New appointments of this type start as Waiting for confirmation | Off |
| Offered when booking | Off hides the type from the **Type** selector ("Not offered") | On |
| The AI can book this type | Lets the AI book it in the chat (step 8). Needs someone in **Who attends by default** | Off |
| Create a Google Meet link | The Google event gets a Meet room. Needs the attendee's Google connected | Off |
| When booked, move the deal to | Moves the customer's open deal to the stage you pick. Only appears if the account has pipelines | Do not move the deal |
| Remind the customer | Reminder message before the appointment (step 7) | Off |
| Message when the customer does not show up | Message for missed appointments (step 7) | Empty |

**How free times are calculated.** For a type and a person, the Agenda offers times that: fall inside the person's working hours; start after now plus the **Minimum notice** and within **Bookable up to**; follow one another every **Duration** (a 60-minute type on 9:00–18:00 offers 9:00, 10:00 … 17:00); and, together with the gaps before and after, do not touch a Waiting or Confirmed appointment of that person or a busy time in their Google Calendar. A person without working hours has no free times.

**Moving the deal when it is booked** only moves it forward, within the same pipeline, and only while the deal is open. The deal history records who moved it (the person, or the AI).

### 5. Set the working hours
**Agenda settings → Working hours.** Administrators pick the person in the selector at the top right of the section; agents set their own.
1. Fill in **Time zone** as in America/Bogota or America/Sao_Paulo.
2. Turn on each day the person attends and set the start and end. A day that is off says "Off". There is one range per day.
3. Press **Save working hours**. You see "Working hours saved."

Nothing exists until you press the button. The Monday to Friday, 09:00 to 18:00 you see the first time is only a suggestion: if you do not save, the person has no free times.

### 6. Connect Google Calendar
1. On the Agenda page, in the **Google Calendar** card, press **Connect Google**.
2. On Google's screen choose the account and allow every permission it asks for (see and edit events on your calendar).
3. You come back to the Agenda with "Google Calendar connected." and the card says "Connected as" followed by your Google email, and that your appointments go to its main calendar.

Each person connects their own account. What is shared:

| Direction | What happens |
|---|---|
| Agenda to Google | Each appointment goes to the **main calendar** of the Google account of the person who attends: title, notes (as description), place and time. A Waiting for confirmation appointment goes as tentative, a Cancelled one is cancelled, a deleted one disappears, and changing who attends moves it to the new person's calendar. It is sent a moment after you save. |
| Google to Agenda | Only busy times, and only from the main calendar. They show as gray **Busy** blocks and are discounted from free times. Events marked as Free (available) and cancelled events do not count. Google events do not become appointments, and appointments sent from the Agenda are not counted twice. Changes in Google can take up to 2 minutes to show in the grid. |

- **Use another account** connects a different Google account. Events already sent stay in the old account.
- **Disconnect** stops the sync. It does not revoke the permission at Google and does not delete events already created. To make Google forget the access, revoke it in your Google account.

### 7. Reminders and missed appointments (WhatsApp by QR)
**Reminder.** In a type, turn on **Remind the customer**, set **How many hours before** (from 0.25 to 168) and write the **Reminder message**. It already comes with a text you can edit. The customer receives it on WhatsApp when all of this is true:
- the appointment is **Confirmed** and has a contact;
- the contact has a conversation on a WhatsApp number connected by QR (the appointment's own conversation, or the most recent conversation of the contact on a QR number);
- the contact is not blocked.

It is sent once. The check runs every 5 minutes, so it can arrive a few minutes late. It is not sent on the official WhatsApp API (outside the 24-hour window only approved templates are allowed).

**Missed appointment.** Write a text in **Message when the customer does not show up**. When someone presses **Did not show up** (in the appointment or in the Risk radar), the customer gets that message the same way. Empty means nothing is sent. The grayed example in the field is only a suggestion: type your text to use it. If the customer answers and AI booking is set up, the AI offers new times.

Markers you can use in both messages:

| Marker | Becomes |
|---|---|
| `{name}` | The customer's first name |
| `{date}` | The day and month, like 21/10 |
| `{time}` | The time, 24-hour, in the attendee's time zone |
| `{type}` | The appointment type's name |
| `{link}` | The Google Meet link, or the place if there is no link |

### 8. Let the AI book
The AI offers times in the chat and books the one the customer accepts. For that, check everything:
1. **A bot is answering on that inbox.** In **Connections** the row says "AI answers as …".
2. **Jev is on and the booking activity is deciding.** Open **Jev** in the menu (AI agent section), save the TypeSafe key with **Check and save** and press **Turn Jev on** (you must agree to send the messages to TypeSafe). In the group **Book appointments**, the activity **Notice a wish to book** must say **Deciding** (it starts that way). If it says Observing, press **Let Jev decide**.
3. **An appointment type with** **The AI can book this type** on, **Offered when booking** on and **Who attends by default** chosen. If several types have the AI switch on, only the first by name is offered.
4. **The attendee has working hours saved** (step 5). Without them the AI finds no free times.
5. **Recommended:** the attendee has Google connected, so busy times block the AI too and the event is created on their calendar.
6. **No rule that forbids confirming appointments**, in the persona's prompt or in "Your rules" of Jev's **Check the reply before sending**. It contradicts booking.

**What the customer lives.**
1. The customer says they want to book, asks which times are free, or picks a time.
2. Unless they already said it, the AI asks which day and which part of the day (morning or afternoon) suit them.
3. It offers up to 3 free times in the next 14 days, in the customer's language and in the attendee's time zone.
4. The customer picks one (or asks for their own, like "Tuesday at 9"). If it is free, the appointment is booked at that moment and the AI confirms it with weekday, date and time.
5. If the type creates a Google Meet link, a last message with the link follows the confirmation.
6. If the customer asks to cancel, the appointment is cancelled with the customer's words as the reason. If they ask to move it, the new time is booked first and only then the old one is cancelled.

**What you see.**
- The appointment in the Agenda, titled like "Consultation — Ana Lopez" (type name, then customer name), linked to the contact, the conversation and the customer's open deal. It is **Confirmed**, or **Waiting for confirmation** if the type needs it (press **Confirm**).
- A private note in the conversation that mentions the attendee, so they get the usual notification (bell, email or push, according to their preferences). Cancellations by the customer leave a note too.
- The event in the attendee's Google Calendar, and the deal moved to the stage you chose in the type.

If a person takes the conversation over, the AI stops answering and booking in it.

## When something fails or pauses

| What you see | What it means and what to do |
|---|---|
| There is no Google Calendar card on the Agenda | The installation has no Google client yet. Ask its administrator to fill in **Super Admin → Settings → Google Calendar** |
| "Could not start the Google connection." | Try again. If it persists, ask the administrator to check the Google client |
| "The Google connection was cancelled." | You closed or refused Google's screen. Press **Connect Google** again |
| "Google did not grant access to the calendar. Connect again and allow every permission." | You unticked a permission. Connect again and leave all of them ticked |
| "Could not connect Google Calendar. Try again." | The connection did not complete. Try again. If you stay more than 10 minutes on Google's screen you land on the home page with no message: start over |
| The card turns red: "Google stopped accepting the connection with …. Connect again to keep syncing." | Press **Connect again**. While it is red nothing syncs and Google busy times are ignored. Appointments saved in the meantime are not sent afterwards: open each one, change something (for example the notes) and press **Save** |
| The connection expires about every 7 days, or only some people can connect | The Google app is still in test mode. The administrator of the installation must publish it in Google Cloud |
| "Could not read N Google Calendar(s) right now; their busy times are missing." | Google did not answer. The Agenda shows without those busy times. Reload in a few minutes |
| "Google Calendar did not answer: its busy times were left out." | The free times may include times that are busy in Google. Check by hand before booking |
| "No free time that day for this type. Pick another day, or set the time by hand." | Check that the attendee has working hours saved, that the day is on, the time zone, the **Minimum notice** and **Bookable up to**, the gaps, and the Waiting or Confirmed appointments of that day |
| "Could not save the appointment. Try again." | The appointment was not saved. Check **What** and **When**, then try again |
| Delete does not work | Only an administrator, the person who created the appointment or the person who attends can delete it |
| An appointment is not in Google | The Google of the person who **attends** (not the one who created it) must be connected and the card must not be red. Then open the appointment, change something and **Save** to send it again |
| The reminder did not arrive | Check: the appointment is **Confirmed**; it has a contact; the contact has a conversation on a QR number that is connected; the contact is not blocked; **Remind the customer** is on; and it is within the hours before. It is not sent on the official WhatsApp API |
| The AI does not offer times | Go through the checklist of step 8, point by point. If Jev is slow or fails, the bot works as it did before and does not book |
| The AI says "Sorry, that time was just taken. Would one of these work for you?" (or its equivalent in the customer's language) | Normal: someone took the time between the offer and the answer. It lists up to 3 other times, or says someone from the team will write |
| The AI says there are no free times in the next 14 days | The attendee is fully booked or has no working hours. It tells the customer that someone from the team will get in touch |
| A reply was held and the conversation went to your team, with a note "tells the customer the appointment is booked, but nothing was booked in the Agenda" | The safety net caught a confirmation that did not book. Book it by hand and answer the customer |
| The AI says the team will take care of it, without offering times | The calendar could not be read at that moment. Try again; if it repeats, tell the administrator of the installation |

## Not included
- No public page for customers to book on their own: the customer books only by chatting with the AI.
- Only Google Calendar (no Outlook or Apple), only the main calendar of the account, and Google events are never imported as appointments.
- Reminders and missed-appointment messages only go by WhatsApp connected by QR. No email or SMS reminders, and no reminders to the team.
- One person per appointment: no rooms, groups or recurring appointments.
- Booking by hand never checks overlaps.
- One range of hours per day in the working hours.
- The AI books one type only, within the next 14 days (at most 40 times).
- Google sync errors are not shown on screen.
