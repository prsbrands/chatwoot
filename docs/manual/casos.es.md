# Cases: sigue lo que el cliente pidió hasta que se resuelva

Cases registra lo que un cliente pidió y no se puede resolver en el momento: una duda que depende de alguien de la empresa, un problema, una solicitud, un reclamo. Cada caso tiene un número, un responsable, un plazo y un desenlace, y puede reunir varias conversaciones del mismo cliente. Está en el menú, en **CRM → Cases**.

*También en: [English](casos.en.md) · [Português](casos.pt.md)*

## Antes de empezar

1. **Cases activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, en las funciones de la cuenta, interruptor **Cases**). Sin eso no aparecen el ítem del menú, el bloque **Cases** del panel de la conversación ni la pestaña **Cases** del contacto.
2. **Quién puede hacer qué.**

| | Agentes | Administradores |
|---|---|---|
| Ver, abrir, editar y trabajar cualquier caso | Sí | Sí |
| Ver **Case metrics** | Sí | Sí |
| **Case settings** (tipos, plazos, detalles, IA, prefijo) | No | Sí |
| **Delete case** | No | Sí |

3. **Tipos de caso.** La primera vez que la cuenta abre Cases, recibe cinco tipos en el idioma de la cuenta (portugués, español o inglés; cualquier otro idioma recibe inglés). Renómbralos, cámbialos o agrega los tuyos en **Case settings** (paso 1).

| English | Español | Português | Plazo | Prioridad por defecto |
|---|---|---|---|---|
| Question | Duda | Dúvida | 24 h | Normal |
| Problem | Problema | Problema | 8 h | High |
| Request | Solicitud | Solicitação | 48 h | Normal |
| Complaint | Reclamo | Reclamação | 4 h | High |
| Billing | Financiero | Financeiro | 24 h | Normal |

4. **Los plazos cuentan horas corridas**, no horas hábiles, desde el momento en que se abre el caso. Se muestran en la zona horaria de tu navegador.
5. **Para que la IA abra casos y responda por el asistente** también necesitas: una *persona* de IA (AI agent → Personas) que responda al menos una bandeja, **Jev** activado con su clave (AI agent → Jev) y que el administrador de la instalación mantenga publicado el workflow "CortexGen Caso" en n8n. El paso 6 y el paso 7 explican cada uno. El resto de Cases funciona sin nada de esto.
6. **Números que conviene conocer.**

| Qué | Valor |
|---|---|
| Número del caso | `PREFIJO-AÑO-0001`, que vuelve a contar desde 1 cada año (por ejemplo `CAS-2026-0001`) |
| Prefijo | De 1 a 8 letras o dígitos, siempre en mayúsculas; `CAS` hasta que lo cambies |
| Casos en la lista | De 100 en 100, luego **Show more** |
| Descripción, nota, "What was done" | hasta 5.000 caracteres |
| Mensaje enviado por el asistente | hasta 2.000 caracteres |
| "When is it this type?" | hasta 500 caracteres |
| Confianza mínima para que la IA elija un tipo | 80% |
| Respuestas enviadas por el asistente | hasta 5 por minuto para toda la cuenta |

## Paso a paso

### 1. Define los tipos de caso (administradores)
**Cases → Case settings.**

- **Number prefix:** escribe las letras y pulsa **Save**. Solo cambia los casos nuevos; los números ya dados se quedan como están.
- **Case types:** la lista muestra cada tipo con su plazo, prioridad, cantidad de detalles y si la IA lo abre o se avisa al cliente. Usa las flechas para cambiar el orden, el lápiz (**Edit type**) para editar y el basurero (**Delete type**) para borrar. Un tipo que ya tiene casos no se puede borrar: desactiva **Available for new cases**.
- **New type** (o el lápiz) abre una ventana con:

| Campo | Qué hace |
|---|---|
| Name | Cómo aparece el tipo en todas partes |
| Color | El punto que identifica el tipo en la lista y en el tablero |
| Due in (hours) | Horas enteras, desde 1. Se cuentan desde que se abre un caso de este tipo. En blanco: **No due date**. Cambiarlo no mueve el plazo de los casos ya abiertos |
| Default priority | Low, Normal, High o Urgent, usada al abrir el caso |
| Default assignee | La persona que recibe los casos nuevos de este tipo (Nobody: nadie) |
| Available for new cases | Desactivado: el tipo ya no aparece al abrir un caso y la IA no lo usa. Los casos existentes lo conservan |
| When the AI notices this kind of request | **The AI does not open this type**, **The AI opens it and keeps helping the customer** o **The AI opens it and hands the conversation to the team** (paso 7) |
| When is it this type? | Aparece cuando la IA está activada para el tipo. Di con tus palabras qué entra en este tipo, hasta 500 caracteres (paso 7) |
| Tell the customer the case number and when it is resolved | Envía al cliente dos avisos en la conversación del caso (paso 8) |
| Details of this type | Información que tu negocio necesita para este tipo de caso. **Add detail** crea uno: **Label**, **Kind** (Text, Number, Date, List o Yes / no), **Options** (solo para List, separadas por comas, al menos una) y **Required to resolve**. **Remove detail** lo borra |

Sobre los detalles: el tipo (Kind) de un detalle no se puede cambiar después de guardado. Renombrar el Label cambia solo el nombre en pantalla. Quitar un detalle lo oculta, pero los casos que ya tenían un valor lo conservan en sus datos.

**Ejemplo: un tipo "Reclamo de garantía".** Name: Reclamo de garantía. Due in: 48. Default priority: High. Default assignee: la jefa de soporte. Details: "Número de pedido" (Text, required to resolve), "Problema" (List: Defectuoso, Producto equivocado, Retraso) y "Foto recibida" (Yes / no). IA: **The AI opens it and keeps helping the customer**, con "When is it this type?": *Un producto llegó dañado o equivocado, o dejó de funcionar dentro de la garantía*. Aviso al cliente: activado.

### 2. Abre un caso
Hay tres maneras:

- **Desde una conversación:** en el panel de la derecha, en el bloque **Cases** (lista los casos activos del cliente), pulsa **New case**. El caso nace vinculado a esa conversación, con el cliente ya completado.
- **Desde un contacto:** abre el contacto, pestaña **Cases** (también lista los casos resueltos y cancelados), pulsa **New case**. El caso queda sin conversación: vincula una después (paso 4).
- **Desde la página Cases:** pulsa **New case** y busca al cliente por nombre, teléfono o correo (al menos 2 letras). **Change** permite elegir a otro cliente.

En la ventana **New case** completa:

- **Type** (ya viene elegido el primer tipo activo) y **Title** ("What does the customer need?"); **Description** es opcional.
- **Priority** y **Assignee** vienen del tipo y se pueden cambiar.
- Abajo aparecen los **detalles** del tipo. Los obligatorios solo se exigen al resolver, no al abrir.

Pulsa **Open case**. El negocio abierto del cliente que se actualizó más recientemente se vincula al caso automáticamente.

### 3. Encuentra tus casos
En **Cases** ves primero los activos, con el plazo más cercano arriba (primero los vencidos, y los casos sin plazo al final).

- **Active / Resolved / Canceled** eligen qué grupo ves. Resolved y Canceled muestran primero los cambiados más recientemente.
- **Everyone / Mine / Unassigned** filtran por responsable.
- **Overdue** muestra solo los atrasados. Los desplegables **All types** y **All priorities** filtran por tipo y prioridad.
- El cuadro de búsqueda (**Number, title or customer**) ignora las tildes.
- Los íconos **List** y **Board** (solo en Active) alternan entre una lista y tres columnas: Open, In progress y Waiting for customer.
- Cada caso muestra su número, tipo, estado, título, cliente, prioridad, responsable y plazo (**Due ...**, u **Overdue since ...** en rojo, o **Waiting for the customer** mientras el plazo está pausado).

Un **número rojo** en **Cases** en el menú cuenta los casos vencidos de toda la cuenta, actualizado cada minuto (un caso que espera al cliente no cuenta como vencido). El **Risk radar** también muestra arriba "N cases are past their due date", con un enlace a cada uno.

### 4. Trabaja un caso
Pulsa un caso para abrirlo.

- **Arriba:** número, tipo, estado, desenlace (una vez resuelto), **Overdue** y **Opened by the AI** cuando corresponden. El lápiz (**Edit**) junto al título cambia el título y la descripción (**Save** / **Cancel**).
- **Botones por estado:**

| Estado | Botones |
|---|---|
| Open | **Start**, **Wait for customer**, **Resolve**, **Cancel case** |
| In progress | **Wait for customer**, **Resolve**, **Cancel case** |
| Waiting for customer | **Start**, **Resolve**, **Cancel case** |
| Resolved o Canceled | **Reopen** (vuelve a In progress) |

- **Columna derecha:** **Assignee**, **Priority**, **Type** y **Due date** cambian apenas eliges. En el plazo, escribe la fecha y la hora y sal del campo; si lo vacías, se quita el plazo. Cambiar el tipo después no recalcula la prioridad, el responsable ni el plazo. Debajo: el **Customer** (abre el contacto), el **Deal** y **Conversations**.
- **Waiting for customer pausa el plazo.** Cuando pulsas **Start** otra vez, el plazo avanza el tiempo que el caso estuvo pausado.
- **Details:** completa la información del tipo y pulsa **Save**. Los marcados con * son obligatorios para resolver.
- **History:** escribe una nota interna y pulsa **Add note**. Las notas son solo del equipo; el cliente nunca las ve. Debajo, en orden de tiempo, todo lo que pasó: quién cambió qué y cuándo, notas, lo que hizo la IA (autor **AI**), eventos automáticos (**System**) y lo que el cliente respondió (**Customer**).
- **Conversations:** cada conversación vinculada se abre al pulsarla. Las otras conversaciones del mismo cliente aparecen como **Link conversation #id**; pulsa una para sumarla al caso.

### 5. Resuelve o cancela un caso
- **Resolve:** primero completa y guarda los detalles obligatorios; si no, la pantalla dice "Fill in ... before resolving the case." o "Save the details before resolving the case." En la ventana, elige el **Outcome** y, si quieres, escribe **What was done** (aparece destacado en el caso).

| Outcome | Úsalo cuando |
|---|---|
| Solved | La necesidad del cliente se atendió (es el valor por defecto) |
| Not applicable | No había nada que hacer |
| Duplicate | La misma solicitud ya existe en otro caso |
| No response from the customer | El cliente nunca respondió |

- **Cancel case:** para un caso abierto por error o que ya no hace falta. Puedes escribir **Why it was canceled**. Queda guardado en la lista **Canceled**.
- **Delete case** (basurero, administradores): borra el caso y todo su historial después de una confirmación. Prefiere cancelar; borrar no se puede deshacer.

### 6. Responde al cliente por el asistente
Úsalo cuando el equipo sabe la respuesta pero quieres que la IA la diga, en el idioma y el tono del cliente. El bloque **Reply through the assistant** aparece cuando el caso está activo y tiene una conversación vinculada.

1. Escribe lo que el cliente debe saber (por ejemplo "The replacement ships on Monday and arrives in 3 business days.").
2. Pulsa **Send answer**, o **Ask the customer** si necesitas algo de él (un número de pedido, una foto).
3. En cerca de un minuto la IA lo publica en la conversación, como el bot de esa bandeja, reescribiendo tu texto en el idioma y el tono del cliente, sin agregar ningún dato.

El resultado aparece en **History** con uno de estos estados:

| Estado | Significado |
|---|---|
| waiting to be sent | Nadie lo tomó todavía. Es normal hasta por un minuto. Si se queda mucho tiempo, la conversación puede estar en una bandeja sin bot, o el workflow está detenido: avisa al administrador de la instalación |
| being sent | La IA lo está escribiendo y publicando |
| sent | Ya está en la conversación. El texto que salió también aparece en el historial |
| could not be sent | La publicación falló. Se avisa al autor; escríbelo de nuevo o responde tú en la conversación |

Con **Ask the customer**, el caso pasa a **Waiting for customer** cuando se envía la pregunta. Cuando el cliente responde (texto, foto o archivo, en cualquier conversación de ese cliente), la respuesta se guarda en **History**, el caso vuelve a **In progress** y se menciona al responsable. Esto solo ocurre después de una pregunta enviada con **Ask the customer**; un caso que pusiste en **Wait for customer** a mano no vuelve solo.

Si la cuenta llegó al tope mensual de IA, o la IA no responde, tu texto sale tal como lo escribiste.

### 7. Deja que la IA abra casos
Cuando un cliente reporta un problema, hace una solicitud o un reclamo, o pide algo que solo una persona puede decidir, la IA puede abrir el caso y darle al cliente su número. Para configurarlo (administradores):

1. **Jev** tiene que estar activado (AI agent → Jev, con la clave de TypeSafe). En la tarjeta de Jev, la actividad **Notice what only the team can solve** (grupo **Open cases for the team**) viene en **Deciding**. Si está en **Observing** o en pausa, la IA no abre casos.
2. En **Case settings**, edita cada tipo que quieras que la IA use y elige en **When the AI notices this kind of request**:
   - **The AI opens it and keeps helping the customer:** el caso se abre, la IA dice el número y sigue respondiendo lo demás que el cliente pregunte, mientras el equipo trabaja en el caso.
   - **The AI opens it and hands the conversation to the team:** el caso se abre, la IA dice el número, deja una nota privada con un resumen y la conversación pasa al equipo. La IA deja de responderla.
3. En **When is it this type?** describe, con tus palabras, qué entra en el tipo. Ejemplo: *Un producto llegó dañado o equivocado, o dejó de funcionar dentro de la garantía.* La IA elige entre tus tipos usando el nombre y este texto. Sé específico: dos tipos con descripciones parecidas la confunden.

Qué esperar:

- La IA solo abre un caso cuando tiene al menos 80% de seguridad sobre el tipo. Si no, responde como siempre.
- El caso nace antes de la respuesta, así que la respuesta puede incluir su número. El título es la primera frase del cliente y la descripción es el mensaje completo. El caso muestra **Opened by the AI**.
- Si el cliente ya tiene un caso activo del mismo tipo, no se abre un segundo caso: el mensaje nuevo se agrega a ese caso como una nota de la IA y la conversación se vincula.
- La IA también le cuenta al cliente en qué etapa están sus casos abiertos, con palabras simples, sin dar fechas y sin decir que algo está resuelto.
- Red de seguridad: si la IA dice "lo voy a consultar con el equipo" pero no se abrió ningún caso, Jev retiene esa respuesta y pasa la conversación al equipo.
- Se avisa al responsable (ver "A quién se avisa"). Si el caso no tiene responsable, se avisa al dueño del negocio abierto del cliente o, si no, al primer administrador de la cuenta.

### 8. Avisa al cliente automáticamente
Activa **Tell the customer the case number and when it is resolved** en el tipo. El cliente recibe entonces, en la conversación del caso y en su idioma (español, portugués o inglés; cualquier otro recibe inglés):

| Cuándo | Mensaje |
|---|---|
| Caso abierto | Registramos tu solicitud con el número CAS-2026-0001. El equipo ya la está revisando y te avisaremos cuando esté resuelta. (en inglés: "We logged your request as ...", en portugués: "Registramos sua solicitação com o número ...") |
| Caso resuelto | Tu solicitud CAS-2026-0001 fue resuelta. Si necesitas algo más, escríbenos por aquí. (en inglés: "Your request ... has been resolved ...", en portugués: "Sua solicitação ... foi resolvida ...") |

El aviso de apertura no se envía en los casos abiertos por la IA, porque su propia respuesta ya da el número. Cuando un aviso no puede salir, **History** dice por qué:

| Mensaje en History | Significado |
|---|---|
| the case has no conversation | Vincula una conversación al caso |
| this inbox does not deliver messages | La bandeja (canal API sin webhook) no puede enviar mensajes al cliente |
| outside the reply window of the channel | Se cerró la ventana de respuesta del canal (WhatsApp oficial, pasadas 24 h) |

### 9. Sigue cómo van los casos
**Cases → Case metrics.** Elige **Last 7 days**, **Last 30 days** o **Last 90 days**. Ves los totales y los mismos números **By type** y **By assignee** ("Nobody" agrupa los que no tienen responsable).

| Columna | Qué cuenta |
|---|---|
| Opened | Casos abiertos en el período |
| By the AI | De esos, cuántos abrió la IA |
| Resolved | Casos resueltos en el período |
| Time to resolve | Tiempo promedio entre abrir y resolver, en horas (el tiempo esperando al cliente cuenta) |
| On time | Parte de los casos resueltos que se resolvieron dentro del plazo (los casos sin plazo quedan fuera; "—" cuando no hay ninguno) |
| Active now | Casos abiertos, en curso o esperando al cliente hoy |
| Overdue now | Casos activos con el plazo vencido hoy (en rojo) |

## A quién se avisa

| Qué pasó | Quién | Cómo |
|---|---|---|
| Un caso se asigna a otra persona (al abrir o al editar) | El nuevo responsable | Nota privada en la conversación del caso que lo menciona (le llega en sus notificaciones). No se envía si te lo asignas a ti mismo |
| La IA abrió un caso | El responsable, o el dueño del negocio abierto del cliente, o el primer administrador | La misma nota privada |
| El cliente respondió una pregunta enviada con **Ask the customer** | El responsable, o el dueño del negocio, o el primer administrador | La misma nota privada |
| La IA no pudo enviar una respuesta escrita por el equipo | Quien la escribió (o el responsable, el dueño del negocio, el primer administrador) | La misma nota privada |
| Un caso se vence | No se avisa a nadie uno por uno | Número rojo en el menú y el **Risk radar** |

Un caso sin conversación no avisa a nadie: solo aparece en **Mine** y en el número rojo.

## Cuando algo falla o se detiene

| Qué ves | Qué hacer |
|---|---|
| "Fill in ... before resolving the case." / "Save the details before resolving the case." | Completa los detalles obligatorios del tipo y pulsa **Save** en el caso |
| "CAS-... is resolved: start not allowed" (u otro estado y acción) | Alguien cambió el caso mientras tanto. Recarga la página y revisa el estado |
| "CAS-... has no conversation with the customer" | Vincula una conversación al caso antes de usar **Reply through the assistant** |
| "This type has cases and cannot be deleted. Turn it off instead." | Edita el tipo y desactiva **Available for new cases** |
| "Could not save. Try again." | Inténtalo de nuevo; si se repite, revisa los valores (una fecha, un número, una opción de la lista) |
| La respuesta se queda en **waiting to be sent** | La conversación está en una bandeja sin bot, o el workflow "CortexGen Caso" está detenido. Avisa al administrador de la instalación, o responde en la conversación |
| **could not be sent** | La IA no pudo publicar en la conversación. Revisa que la bandeja esté conectada y escríbela de nuevo |
| La IA nunca abre un caso | Revisa: **Cases** activado en la cuenta; Jev activado, con la actividad **Notice what only the team can solve** en **Deciding**; el tipo con la IA activada y **Available for new cases** activado; una persona respondiendo en esa bandeja |
| La IA abrió un caso del tipo equivocado | Mejora **When is it this type?** y el nombre de los tipos |
| El cliente no recibió el aviso | Mira la tabla del paso 8 |
| El número rojo no desaparece | Cuenta los casos activos vencidos de toda la cuenta; resuélvelos o cancélalos, o cambia su plazo |

## No incluido
- Sin una página para que el cliente siga el caso: el cliente solo recibe los dos avisos del paso 8.
- Plazos en horario hábil: cuentan horas corridas.
- Sin recordatorio ni escalamiento automático cuando un caso se vence (solo el número rojo y el **Risk radar**).
- La IA no completa los detalles del tipo; los completa el equipo.
- Sin reparto automático de casos por carga o por turnos: el responsable es el predeterminado del tipo o quien tú elijas.
