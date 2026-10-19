# Agenda: citas, horarios de atención, Google Calendar y agendamiento por la IA

La Agenda es el calendario donde tu equipo agenda citas con los clientes y ve quién atiende cada una. Puede compartirlas con Google Calendar, y la IA puede agendar sola en el chat. Está en el menú, cerca de la parte de arriba, como **Agenda**. Los tipos de cita y los horarios de atención están en **Agenda settings** (el ícono de engranaje arriba a la derecha de la página de la Agenda).

*También en: [English](agenda.en.md) · [Português](agenda.pt.md)*

## Antes de empezar

1. **No hay nada que activar.** La Agenda está activa en todas las cuentas (no hay interruptor en el Super Admin). Administradores y agentes la ven.
2. **Zonas horarias.** La grilla usa la zona horaria de tu navegador. Los **horarios de atención** de cada persona tienen su propia zona horaria (por ejemplo America/Bogota). Los horarios que la IA ofrece a los clientes, y la fecha y la hora de los recordatorios, usan la zona horaria de quien atiende.
3. **Google Calendar es opcional**, y necesita que el administrador de la instalación agregue una vez el cliente OAuth de Google, en **Super Admin → Settings → Google Calendar** (campos "Google Calendar client ID" y "Google Calendar client secret"; la dirección que hay que autorizar en Google es `<tu dirección>/google_calendar/callback`). No es la pantalla "Google" que se usa para Gmail y el inicio de sesión. Mientras no esté hecho, la tarjeta de Google no aparece en la página de la Agenda. Después, cada persona conecta su propia cuenta de Google.
4. **Para que la IA agende citas** hace falta más: mira el paso 8.
5. **Quién puede hacer qué:**

| Acción | Administrador | Agente |
|---|---|---|
| Ver la agenda de todo el equipo, agendar y editar citas, cambiar su estado | Sí | Sí |
| Eliminar una cita | Cualquiera | Solo las que creó o atiende |
| Crear, editar y eliminar tipos de cita | Sí | No (ve la lista) |
| Editar horarios de atención | Los de cualquiera | Los suyos |
| Conectar Google Calendar | El suyo | El suyo |

## Paso a paso

### 1. Lee la Agenda
- **Day** y **Week** cambian la vista. La semana empieza el lunes. Las flechas avanzan y retroceden, **Today** vuelve a hoy y el título muestra el período.
- El selector de arriba a la derecha elige de quién ves las citas: **My agenda**, **Whole team** o una persona.
- Cada cita es un bloque con su título, la hora y el nombre del cliente (y quién atiende, cuando no estás viendo **My agenda**). Las citas que se superponen comparten el ancho.
- Los bloques grises **Busy** son horas que esa persona ya tiene ocupadas en Google Calendar, y **Busy all day** aparece arriba del día. Solo se ven para quienes tienen Google conectado.
- La línea roja es la hora actual.

### 2. Agenda una cita
Tres formas: haz clic en una hora vacía de la grilla (se redondea a la media hora); pulsa **New appointment** (empieza en la próxima media hora); o, en una conversación de una cuenta con Sales Pipeline, abre la tarjeta **Deal** y pulsa **Appointment**, que ya rellena el cliente y el negocio.

| Campo | Qué es |
|---|---|
| What | El título. Obligatorio. Por ejemplo "Demo call, visit, consultation…" |
| Type | Uno de tus tipos de cita, o "No type". Solo aparece si creaste tipos |
| When | Fecha y hora. Obligatorio |
| How long | 15, 30, 45, 60, 90 o 120 minutos |
| Free times that day | Aparece después de elegir un tipo. Haz clic en una hora para rellenar **When** |
| Who attends | La persona que va a atender. Empieza siendo tú |
| Who is being attended | El cliente. Busca por nombre, teléfono o correo (desde 2 letras). La × lo quita |
| Where | Dirección, enlace de videollamada o teléfono |
| Notes | Hasta 2.000 caracteres |

Pulsa **Save** (se habilita cuando **What** y **When** están rellenos).
- Elegir un **Type** rellena la duración, el lugar (si está vacío) y, en las citas nuevas, quién atiende por defecto.
- **Free times that day** muestra los horarios libres de ese tipo para la persona que atiende en el día de **When**. Siempre puedes poner la hora a mano: agendar a mano no revisa superposiciones.
- Un tipo con **Needs confirmation** crea la cita como **Waiting for confirmation**. En otro caso queda **Confirmed**.
- Cuando el tipo crea un enlace de Google Meet y Google ya sincronizó la cita, al abrirla aparece **Join the Google Meet**.

### 3. Sigue cada cita hasta el final
Haz clic en una cita. Arriba ves su estado y los botones de los otros estados, además de **Delete**.

| Estado | Botón que lo pone | Cómo se ve |
|---|---|---|
| Waiting for confirmation | (el estado inicial de los tipos que lo piden) | Ámbar con línea punteada |
| Confirmed | **Confirm** | Azul |
| Done | **Mark as done** | Verde azulado |
| Did not show up | **Did not show up** | Rojo, tachado |
| Cancelled | **Cancel** | Gris, tachado |

- Las citas Waiting y Confirmed ocupan el tiempo de la persona: no se ofrece ningún horario libre encima de ellas. Las demás liberan el tiempo.
- Los recordatorios solo se envían para citas **Confirmed**.
- Si la cuenta tiene Sales Pipeline, el **Risk radar** lista las citas que terminaron en los últimos 30 días sin un resultado, con los botones **Mark as done** y **Did not show up**. Úsalos: también activan el mensaje de ausencia (paso 7).

### 4. Crea los tipos de cita
**Agenda settings → Appointment types → New type** (administradores). El lápiz edita un tipo y el basurero lo elimina (las citas ya agendadas se quedan, sin tipo). Cada tipo muestra su duración, quién atiende por defecto y etiquetas como "Needs confirmation", "The AI books this type" o "Not offered".

| Campo | Qué hace | Límites y valor por defecto |
|---|---|---|
| Name | El nombre que se elige. Obligatorio | |
| Duration (min) | Cuánto dura | 5 a 1.440. Por defecto 60 |
| Gap before (min), Gap after (min) | Espacio libre que se deja alrededor de cada cita | 0 a 240. Por defecto 0 |
| Minimum notice (min) | Con cuánta anticipación desde ahora se puede agendar | 0 a 43.200. Por defecto 120 |
| Bookable up to (days ahead) | Cuántos días hacia adelante se puede agendar | 1 a 365. Por defecto 60 |
| Who attends by default | La persona cuya agenda se usa para los horarios libres. "Whoever books" lo deja abierto | |
| Where | Dirección, enlace de videollamada o teléfono | |
| Needs confirmation | Las citas nuevas de este tipo empiezan como Waiting for confirmation | Desactivado |
| Offered when booking | Desactivado oculta el tipo del selector **Type** ("Not offered") | Activado |
| The AI can book this type | Permite que la IA lo agende en el chat (paso 8). Necesita una persona en **Who attends by default** | Desactivado |
| Create a Google Meet link | El evento de Google recibe una sala de Meet. Necesita el Google de quien atiende conectado | Desactivado |
| When booked, move the deal to | Mueve el negocio abierto del cliente a la etapa que elijas. Solo aparece si la cuenta tiene embudos | Do not move the deal |
| Remind the customer | Mensaje de recordatorio antes de la cita (paso 7) | Desactivado |
| Message when the customer does not show up | Mensaje para las citas a las que el cliente no vino (paso 7) | Vacío |

**Cómo se calculan los horarios libres.** Para un tipo y una persona, la Agenda ofrece horas que: caen dentro del horario de atención de la persona; empiezan después de ahora más el **Minimum notice** y dentro de **Bookable up to**; van una tras otra cada **Duration** (un tipo de 60 minutos en 9:00–18:00 ofrece 9:00, 10:00 … 17:00); y, junto con los espacios antes y después, no tocan una cita Waiting o Confirmed de esa persona ni una hora ocupada de su Google Calendar. Una persona sin horario de atención no tiene horarios libres.

**Mover el negocio al agendar** solo lo mueve hacia adelante, dentro del mismo embudo, y solo mientras el negocio está abierto. El historial del negocio registra quién lo movió (la persona o la IA).

### 5. Define los horarios de atención
**Agenda settings → Working hours.** Los administradores eligen la persona en el selector de arriba a la derecha de la sección; los agentes definen los suyos.
1. Rellena **Time zone** como en America/Bogota o America/Sao_Paulo.
2. Activa cada día en que la persona atiende y define el inicio y el fin. Un día desactivado dice "Off". Hay un solo rango por día.
3. Pulsa **Save working hours**. Verás "Working hours saved."

No existe nada hasta que pulses el botón. El lunes a viernes, de 09:00 a 18:00, que ves la primera vez es solo una sugerencia: si no guardas, la persona no tiene horarios libres.

### 6. Conecta Google Calendar
1. En la página de la Agenda, en la tarjeta **Google Calendar**, pulsa **Connect Google**.
2. En la pantalla de Google elige la cuenta y permite todos los permisos que pide (ver y editar eventos en tu calendario).
3. Vuelves a la Agenda con "Google Calendar connected." y la tarjeta dice "Connected as" seguido de tu correo de Google, y que tus citas van a su calendario principal.

Cada persona conecta su propia cuenta. Qué se comparte:

| Dirección | Qué pasa |
|---|---|
| De la Agenda a Google | Cada cita va al **calendario principal** de la cuenta de Google de quien atiende: título, notas (como descripción), lugar y hora. Una cita Waiting for confirmation va como provisional, una Cancelled se cancela, una eliminada desaparece, y cambiar quién atiende la mueve al calendario de la nueva persona. Se envía un momento después de guardar. |
| De Google a la Agenda | Solo las horas ocupadas, y solo del calendario principal. Se ven como bloques grises **Busy** y se descuentan de los horarios libres. Los eventos marcados como Libre (disponible) y los cancelados no cuentan. Los eventos de Google no se convierten en citas, y las citas enviadas desde la Agenda no se cuentan dos veces. Los cambios en Google pueden tardar hasta 2 minutos en aparecer en la grilla. |

- **Use another account** conecta otra cuenta de Google. Los eventos ya enviados se quedan en la cuenta anterior.
- **Disconnect** detiene la sincronización. No revoca el permiso en Google ni elimina los eventos ya creados. Para que Google olvide el acceso, revócalo en tu cuenta de Google.

### 7. Recordatorios y citas perdidas (WhatsApp por QR)
**Recordatorio.** En un tipo, activa **Remind the customer**, define **How many hours before** (de 0,25 a 168) y escribe el **Reminder message**. Ya viene con un texto que puedes editar. El cliente lo recibe por WhatsApp cuando se cumple todo esto:
- la cita está **Confirmed** y tiene un contacto;
- el contacto tiene una conversación en un número de WhatsApp conectado por QR (la conversación de la propia cita, o la conversación más reciente del contacto en un número QR);
- el contacto no está bloqueado.

Se envía una sola vez. La revisión corre cada 5 minutos, así que puede llegar unos minutos tarde. No se envía por la API oficial de WhatsApp (fuera de la ventana de 24 horas solo se permiten plantillas aprobadas).

**Cita perdida.** Escribe un texto en **Message when the customer does not show up**. Cuando alguien pulsa **Did not show up** (en la cita o en el Risk radar), el cliente recibe ese mensaje de la misma forma. Vacío significa que no se envía nada. El ejemplo en gris del campo es solo una sugerencia: escribe tu texto para usarlo. Si el cliente responde y el agendamiento por la IA está configurado, la IA ofrece nuevos horarios.

Marcadores que puedes usar en los dos mensajes:

| Marcador | Se convierte en |
|---|---|
| `{name}` | El primer nombre del cliente |
| `{date}` | El día y el mes, como 21/10 |
| `{time}` | La hora, en formato de 24 horas, en la zona horaria de quien atiende |
| `{type}` | El nombre del tipo de cita |
| `{link}` | El enlace de Google Meet, o el lugar si no hay enlace |

### 8. Deja que la IA agende
La IA ofrece horarios en el chat y agenda el que el cliente acepta. Para eso, revisa todo:
1. **Un bot está respondiendo en esa bandeja.** En **Connections** la fila dice "AI answers as …".
2. **Jev está activo y la actividad de agendamiento está decidiendo.** Abre **Jev** en el menú (sección AI agent), guarda la clave de TypeSafe con **Check and save** y pulsa **Turn Jev on** (debes aceptar el envío de los mensajes a TypeSafe). En el grupo **Book appointments**, la actividad **Notice a wish to book** debe decir **Deciding** (empieza así). Si dice Observing, pulsa **Let Jev decide**.
3. **Un tipo de cita con** **The AI can book this type** activado, **Offered when booking** activado y **Who attends by default** elegido. Si varios tipos tienen el interruptor de la IA activado, solo se ofrece el primero por nombre.
4. **Quien atiende tiene horarios de atención guardados** (paso 5). Sin ellos la IA no encuentra horarios libres.
5. **Recomendado:** quien atiende tiene Google conectado, para que las horas ocupadas también bloqueen a la IA y el evento se cree en su calendario.
6. **Ninguna regla que prohíba confirmar citas**, en el prompt de la persona o en "Your rules" de **Check the reply before sending** de Jev. Contradice el agendamiento.

**Lo que vive el cliente.**
1. El cliente dice que quiere agendar, pregunta qué horarios hay libres o elige una hora.
2. Si no lo dijo ya, la IA pregunta qué día y qué parte del día (mañana o tarde) le convienen.
3. Ofrece hasta 3 horarios libres de los próximos 14 días, en el idioma del cliente y en la zona horaria de quien atiende.
4. El cliente elige uno (o pide el suyo, como "el martes a las 9"). Si está libre, la cita se agenda en ese momento y la IA la confirma con día de la semana, fecha y hora.
5. Si el tipo crea un enlace de Google Meet, un último mensaje con el enlace sigue a la confirmación.
6. Si el cliente pide cancelar, la cita se cancela con las palabras del cliente como motivo. Si pide moverla, primero se agenda el horario nuevo y solo después se cancela el anterior.

**Lo que ves tú.**
- La cita en la Agenda, con un título como "Consultation — Ana Lopez" (nombre del tipo y luego nombre del cliente), vinculada al contacto, a la conversación y al negocio abierto del cliente. Queda **Confirmed**, o **Waiting for confirmation** si el tipo lo pide (pulsa **Confirm**).
- Una nota privada en la conversación que menciona a quien atiende, para que reciba la notificación de siempre (campana, correo o push, según sus preferencias). Las cancelaciones hechas por el cliente también dejan una nota.
- El evento en el Google Calendar de quien atiende, y el negocio movido a la etapa que elegiste en el tipo.

Si una persona toma la conversación, la IA deja de responder y de agendar en ella.

## Cuando algo falla o se detiene

| Lo que ves | Qué significa y qué hacer |
|---|---|
| No hay tarjeta de Google Calendar en la Agenda | La instalación todavía no tiene el cliente de Google. Pide a su administrador que complete **Super Admin → Settings → Google Calendar** |
| "Could not start the Google connection." | Inténtalo de nuevo. Si persiste, pide al administrador que revise el cliente de Google |
| "The Google connection was cancelled." | Cerraste o rechazaste la pantalla de Google. Pulsa **Connect Google** otra vez |
| "Google did not grant access to the calendar. Connect again and allow every permission." | Desmarcaste un permiso. Conecta de nuevo y deja todos marcados |
| "Could not connect Google Calendar. Try again." | La conexión no se completó. Inténtalo de nuevo. Si pasas más de 10 minutos en la pantalla de Google, llegas a la página de inicio sin ningún mensaje: empieza otra vez |
| La tarjeta se pone roja: "Google stopped accepting the connection with …. Connect again to keep syncing." | Pulsa **Connect again**. Mientras esté roja no se sincroniza nada y se ignoran las horas ocupadas de Google. Las citas guardadas mientras tanto no se envían después: abre cada una, cambia algo (por ejemplo las notas) y pulsa **Save** |
| La conexión vence más o menos cada 7 días, o solo algunas personas pueden conectar | La app de Google sigue en modo de prueba. El administrador de la instalación debe publicarla en Google Cloud |
| "Could not read N Google Calendar(s) right now; their busy times are missing." | Google no respondió. La Agenda se muestra sin esas horas ocupadas. Recarga en unos minutos |
| "Google Calendar did not answer: its busy times were left out." | Los horarios libres pueden incluir horas que están ocupadas en Google. Revisa a mano antes de agendar |
| "No free time that day for this type. Pick another day, or set the time by hand." | Revisa que quien atiende tenga horarios de atención guardados, que el día esté activado, la zona horaria, el **Minimum notice** y el **Bookable up to**, los espacios y las citas Waiting o Confirmed de ese día |
| "Could not save the appointment. Try again." | La cita no se guardó. Revisa **What** y **When** e inténtalo de nuevo |
| Eliminar no funciona | Solo un administrador, quien creó la cita o quien la atiende puede eliminarla |
| Una cita no está en Google | El Google de la persona que **atiende** (no de quien la creó) debe estar conectado y la tarjeta no debe estar roja. Luego abre la cita, cambia algo y pulsa **Save** para enviarla otra vez |
| El recordatorio no llegó | Revisa: la cita está **Confirmed**; tiene un contacto; el contacto tiene una conversación en un número QR que está conectado; el contacto no está bloqueado; **Remind the customer** está activado; y ya estás dentro de las horas previas. No se envía por la API oficial de WhatsApp |
| La IA no ofrece horarios | Recorre la lista del paso 8, punto por punto. Si Jev está lento o falla, el bot funciona como antes y no agenda |
| La IA dice "Sorry, that time was just taken. Would one of these work for you?" (o su equivalente en el idioma del cliente) | Normal: alguien ocupó el horario entre la oferta y la respuesta. Lista hasta 3 horarios más, o dice que alguien del equipo escribirá |
| La IA dice que no hay horarios libres en los próximos 14 días | Quien atiende tiene la agenda llena o no tiene horarios de atención. Le avisa al cliente que alguien del equipo se pondrá en contacto |
| Una respuesta quedó retenida y la conversación pasó a tu equipo, con una nota "tells the customer the appointment is booked, but nothing was booked in the Agenda" | La red de seguridad detectó una confirmación que no agendó nada. Agenda a mano y responde al cliente |
| La IA dice que el equipo se encargará, sin ofrecer horarios | No se pudo leer el calendario en ese momento. Inténtalo de nuevo; si se repite, avisa al administrador de la instalación |

## No incluido
- Sin página pública para que los clientes agenden por su cuenta: el cliente agenda solo conversando con la IA.
- Solo Google Calendar (sin Outlook ni Apple), solo el calendario principal de la cuenta, y los eventos de Google nunca se importan como citas.
- Los recordatorios y los mensajes de cita perdida solo salen por WhatsApp conectado por QR. Sin recordatorios por correo ni SMS, y sin recordatorios para el equipo.
- Una persona por cita: sin salas, grupos ni citas recurrentes.
- Agendar a mano nunca revisa superposiciones.
- Un solo rango de horas por día en los horarios de atención.
- La IA agenda un solo tipo, dentro de los próximos 14 días (como máximo 40 horarios).
- Los errores de sincronización con Google no se muestran en pantalla.
