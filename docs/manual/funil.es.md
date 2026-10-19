# Embudo de ventas, Risk radar y Tareas: del primer mensaje al negocio cerrado

Estas tres pantallas trabajan juntas. El **Pipeline** muestra todos los negocios en un tablero, etapa por etapa. El **Risk radar** lista los negocios que se quedaron callados y pueden morir sin respuesta. **Tasks** guarda lo que se acordó, con fecha límite. En el menú: **Risk radar** está cerca de la parte de arriba, **Pipeline** y **Tasks** están en la sección **CRM**. Dentro de cada conversación, la tarjeta **Deal** del panel lateral muestra el negocio del cliente.

*También en: [English](funil.en.md) · [Português](funil.pt.md)*

## Antes de empezar

1. **Sales Pipeline activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, en las funciones de la cuenta). Sin eso, las tres pantallas y la tarjeta **Deal** no aparecen.
2. **Quién puede hacer qué.** Administradores y agentes ven y usan el Pipeline, el Risk radar y Tasks, mueven negocios y crean tareas. Solo los administradores crean embudos y cambian etapas (los botones **Pipeline settings** y **New pipeline** no aparecen para los agentes). Una tarea la puede eliminar quien la creó o un administrador.
3. **Los negocios aparecen solos.** Cuando un contacto escribe por primera vez en una bandeja donde el bot de IA está activo, se abre un negocio para él en la primera etapa abierta del embudo por defecto. Un contacto tiene un negocio abierto a la vez. También puedes pulsar **Create deal** en la tarjeta **Deal** de una conversación. (Si el bot no está activo en la bandeja, revisa **Connections**: el negocio no se crea.)
4. **Para que la IA mueva negocios y dé puntajes** necesitas Jev activado (mira el paso 5).
5. **Para el grupo "Bot follows up" del radar** necesitas el seguimiento activado en la persona de esa bandeja (**Follow up after N hours of silence**, en Bot Personas).

## Paso a paso

### 1. Lee el pipeline
**CRM → Pipeline.** Cada columna es una etapa. Arriba de la columna ves cuántos negocios tiene y su valor total. Los negocios de una columna van del movido más recientemente al más antiguo.

Cada tarjeta muestra:
- el título (el nombre o el teléfono del contacto), el nombre del contacto cuando es distinto, el valor y hace cuánto está en la etapa;
- un **punto de color** cuando el negocio está en riesgo: ámbar es "Going cold", rojo es "Critical" (pasa el cursor para leerlo y ver hace cuánto fue la última interacción);
- una **insignia con un número**, el puntaje de 0 a 100 (pasa el cursor para ver Hot, Warm o Cold);
- una caja ámbar cuando Jev tiene una sugerencia (paso 5);
- el enlace **Open conversation**.

Arriba: el **selector de embudo** (la elección queda en el enlace), el botón **Only at risk** (muestra solo los negocios que se enfrían o críticos, y desactiva el arrastre mientras está activo) y, para los administradores, **Pipeline settings** y **New pipeline**.

### 2. Mueve un negocio
Arrastra la tarjeta a otra columna. Ves "Deal moved to" seguido del nombre de la etapa.
- Arrastrar a una etapa **Lost** pregunta "Why was this deal lost?". Escribe el motivo y pulsa **Mark as lost**. Si cancelas, la tarjeta vuelve.
- Arrastrar a **Won** no pregunta nada.
- Para reabrir un negocio, arrástralo de vuelta a una etapa abierta.
- Cada movimiento queda en el historial del negocio: quién lo movió (una persona, "The AI" o el sistema) y, en los perdidos, el motivo.

### 3. Usa la tarjeta Deal dentro de la conversación
En el panel lateral de la conversación, abre **Deal**. Si el contacto no tiene negocio ves "No deal for this contact yet." y **Create deal**. Si tiene, ves (el negocio abierto, o el más reciente):

| Parte | Qué hace |
|---|---|
| Pipeline | Aparece cuando la cuenta tiene más de un embudo. Elegir otro mueve el negocio a la primera etapa abierta de ese embudo |
| Stage | Mueve el negocio. Elegir una etapa Lost pide el motivo |
| Value | El valor en la moneda del negocio (unidades enteras). Se guarda al salir del campo. Los negocios nuevos usan USD, o BRL en las cuentas en portugués |
| Riesgo y puntaje | El estado ("On track", "Going cold" o "Critical"), hace cuánto fue la última interacción, cuánto tolera la etapa, y el puntaje con los factores que lo formaron |
| History | Los últimos 5 movimientos, con el motivo |
| Next steps | Las tareas pendientes y las próximas citas del negocio. Botones **Task** y **Appointment**. Sin ninguna, avisa "No next step yet. Add a task so this deal does not go quiet." |
| Open pipeline | Te lleva al tablero |

Si Jev tiene una sugerencia, una caja ámbar muestra "Jev suggests moving to … (NN%)" con **Accept** y **Dismiss**.

### 4. Configura embudos y etapas (administradores)
**Pipeline → New pipeline** crea un embudo con las etapas modelo en el idioma de la cuenta (en inglés: New lead, Contacted, Qualifying, Proposal sent, Negotiating, Won, Lost). Puedes renombrarlas o eliminarlas. **Pipeline → Pipeline settings** abre la ventana de etapas:

| Campo | Qué hace |
|---|---|
| Pipeline name | Renombra el embudo |
| Make default | El embudo por defecto recibe los negocios que se abren solos. Solo uno es el por defecto |
| Delete pipeline | Solo se puede eliminar un embudo vacío y que no sea el por defecto |
| Name | El nombre de la etapa |
| Expected hours | Cuánto puede quedarse un negocio en la etapa antes de contar como frío. Vacío significa 24 |
| Needs a person | Cuando la IA mueve un negocio a esta etapa, la conversación se abre para tu equipo, con una nota |
| Flechas (Move up, Move down) | Cambian el orden |
| Basurero (Delete stage) | Solo para etapas abiertas sin negocios. Una etapa con negocios no se puede eliminar: muévelos antes |
| Add stage | Crea una etapa antes de Won y Lost |

Cada campo se guarda solo al salir de él. **Done** cierra la ventana. Todo embudo tiene exactamente una etapa **Won** y una **Lost**; no se pueden agregar ni eliminar.

### 5. Deja que Jev mueva los negocios
Abre **Jev** en el menú (sección AI agent). Activa Jev si está apagado (guarda la clave de TypeSafe y pulsa **Turn Jev on**). En el grupo **Sales pipeline**, la actividad **Move the deal along the pipeline** empieza en **Observing**: solo cuenta lo que haría. Para que actúe, pulsa **Let Jev decide**; puedes volver a observar cuando quieras.

Cómo decide (lee cada mensaje del cliente, una vez por ráfaga de mensajes):

| Confianza de Jev | Qué pasa |
|---|---|
| 80% o más | Mueve el negocio solo. El historial dice "The AI moved it to …" con el porcentaje como motivo |
| Entre 50% y 80% | Deja una sugerencia en la tarjeta, con **Accept** y **Dismiss** |
| El cliente compró con claridad ("Won") | Siempre una sugerencia, con cualquier confianza desde 50% |
| Una persona movió el negocio en las últimas 24 horas | Solo sugiere |

- Solo mueve **hacia adelante**, nunca hacia atrás, y **nunca a Lost**: la IA no conoce el motivo.
- Solo elige entre las etapas que vinieron con el modelo (las cinco primeras, de New lead a Negotiating). A las etapas que agregues tú mismo solo se llega a mano.
- Cualquier movimiento hecho por una persona borra una sugerencia pendiente.
- Si la IA mueve un negocio a una etapa marcada **Needs a person**, la conversación se abre para tu equipo con una nota ("The deal reached … which needs a person. The conversation was opened for the team.").

### 6. Entiende el riesgo y el puntaje
**Riesgo.** Cada 5 minutos el Pipeline recalcula cuánto lleva cada negocio abierto sin una interacción real: un mensaje público hacia o desde el cliente, en cualquier conversación del contacto. Las notas privadas y los mensajes del sistema no cuentan.

| Estado | Cuándo | Ejemplo con una etapa de 24 horas esperadas |
|---|---|---|
| On track | Menos tiempo que las **Expected hours** de la etapa | Menos de 24 h |
| Going cold | Las Expected hours o más | Desde 24 h |
| Critical | 3 veces las Expected hours o más | Desde 72 h |

**Puntaje.** Un número de 0 a 100 hecho con una fórmula, nunca a ojo, y siempre mostrado con sus factores. Empieza en 30 y suma o resta:

| Factor | Puntos |
|---|---|
| Aceptó un próximo paso; pidió precio o propuesta; quiere comprar o empezar | +12 cada uno (hasta 3) |
| Objeción de precio; no es el momento; comparando o con duda | −8 cada uno (hasta 3) |
| Describió la necesidad; mencionó un presupuesto; mencionó un plazo; decide o dijo quién decide | +5 cada uno (hasta 4) |
| Interacción reciente / enfriándose / sin interacción hace mucho | +10 / −10 / −20 |

El puntaje es **Hot** desde 70, **Warm** desde 40 y **Cold** por debajo de 40. Hasta que Jev encuentre al menos dos señales en la conversación no hay puntaje ("No score yet: Jev needs at least two signals from the conversation."). Las señales las da Jev, así que necesita que la actividad del paso 5 esté en Observing o Deciding.

### 7. Trabaja el Risk radar
Abre **Risk radar** en el menú. Lista los negocios abiertos que se enfrían o están críticos, los más urgentes primero. Arriba, etiquetas pequeñas cuentan cada grupo.

| Grupo | Significado |
|---|---|
| Critical | Callado hace 3 veces el tiempo esperado de la etapa o más |
| Going cold | Callado hace más que el tiempo esperado de la etapa |
| Bot follows up | Estaría frío, pero la IA va a retomar la conversación por su cuenta |

"Bot follows up" aparece cuando: la persona de la bandeja tiene el seguimiento activado, la conversación está en un número de WhatsApp conectado por QR que está conectado, sigue con el bot (sin persona asignada), el bot habló al final, el cliente escribió en los últimos 7 días, los seguimientos de ese silencio no se agotaron y la zona horaria de la bandeja no es UTC.

Cada fila muestra: el grupo, el negocio y su valor, el embudo y la etapa, "Quiet …", el puntaje, quién lo tiene y el seguimiento.
- **Quién lo tiene:** "With …" (la persona asignada a la conversación), "With the AI (…)" o "No owner".
- **Seguimiento:** "The AI follows up …" con la hora prevista, "The AI follows up soon" (la hora ya pasó y espera la ventana de envío de 8:00 a 20:00 o el límite diario del número), o "No follow-up scheduled".
- Haz clic en la fila para abrir la conversación (o el Pipeline, si el negocio no tiene).
- **Take over** te asigna la conversación y la abre, y la IA deja de responder. Ves "The conversation is yours now: the AI stopped answering it." El botón no aparece cuando ya la tiene una persona.

Arriba de la lista puede haber bloques que piden acción:
- Un bloque que dice "N appointments already happened — did the customers show up?": pulsa **Mark as done** o **Did not show up** para cada una.
- Un bloque que dice "N open deals have no next step": negocios sin tarea pendiente ni cita próxima, en el negocio o en el contacto. Haz clic en uno para abrirlo y agregar lo que sigue. Es el único número que debería ser cero. Van primero los más antiguos en su etapa, hasta 50.
- Un bloque que dice "N cases are past their due date", cuando la cuenta usa Cases.

Cuando no hay nada en riesgo ves "No deal at risk. Every open deal had an interaction within its stage's time."

### 8. Guarda lo acordado en Tasks
**CRM → Tasks.** Pulsa **New task** y rellena:

| Campo | Qué es |
|---|---|
| What needs to be done | El título. Obligatorio |
| Due | Fecha y hora. Opcional |
| Who does it | Una persona, o "Nobody". Empieza siendo tú |
| Notes | Hasta 2.000 caracteres |

Pulsa **Save**. Una tarea hecha aquí no está ligada a ningún negocio. Para ligar una tarea a un negocio, pulsa **Task** en la tarjeta **Deal** de la conversación.
- Los botones **To do** y **Done** eligen qué lista ves, y **Mine** y **Everyone's** de quién son las tareas. La lista To do se agrupa en **Overdue**, **Today**, **Upcoming** y **No due date**. La lista Done muestra las últimas 100.
- El círculo a la izquierda de una tarea la marca como hecha (**Mark as done**) o la reabre (**Reopen**). El lápiz edita y el basurero elimina; aparecen al pasar el cursor sobre la tarea.
- La fecha límite se pone roja cuando pasa. El enlace de la tarea abre la conversación de su negocio, o el contacto.

## Cuando algo falla o se detiene

| Lo que ves | Qué significa y qué hacer |
|---|---|
| Pipeline, Risk radar, Tasks o la tarjeta Deal no aparecen | Sales Pipeline no está activado en la cuenta. Pregunta al administrador de la instalación |
| Un cliente escribió y no apareció ningún negocio | La bandeja no tiene un bot de IA activo (revisa **Connections**), el contacto está bloqueado, o el contacto ya tiene un negocio abierto (búscalo en el tablero). Puedes pulsar **Create deal** en la conversación |
| "Could not update the pipeline" | El cambio no se guardó. El tablero se recarga; inténtalo de nuevo |
| "Only an empty pipeline that is not the default can be deleted. Move its deals or pick another default first." | Mueve sus negocios a otro embudo, o pulsa antes **Make default** en otro embudo |
| Una etapa no se elimina | Tiene negocios. Muévelos antes a otra etapa |
| Una tarjeta vuelve a su lugar tras soltarla en una etapa Lost | Cancelaste la ventana del motivo. Suéltala de nuevo y escribe el motivo |
| Jev no mueve negocios | Revisa: Jev está activo y **Move the deal along the pipeline** dice **Deciding**; el destino es una etapa del modelo y está adelante de la actual; una persona no movió el negocio en las últimas 24 horas (entonces solo sugiere); la confianza llegó a 80% |
| "No score yet: Jev needs at least two signals from the conversation." | Normal al comienzo. Aparece cuando el cliente da más información |
| "Could not take over the conversation. Try again." | La asignación falló. Inténtalo de nuevo, o abre la conversación y asígnatela |
| Una fila del radar dice "No follow-up scheduled" | La IA no retomará esa conversación: mira las condiciones de "Bot follows up" en el paso 7. Toma la conversación o escribe tú al cliente |
| El botón de eliminar de una tarea muestra un error | Solo quien creó la tarea o un administrador puede eliminarla |
| El Risk radar está vacío | Bien: ningún negocio abierto pasó del tiempo esperado de su etapa |

## No incluido
- Sin botón "New deal" en el tablero: los negocios nacen de las conversaciones. Y no hay forma de eliminar un negocio desde la pantalla.
- Jev nunca mueve un negocio a Lost ni hacia atrás, ni a etapas que agregues tú mismo.
- Nadie recibe aviso de tareas vencidas, de sugerencias de Jev ni de cambios en el radar: hay que mirar las pantallas.
- Sin pronósticos ni informes de ingresos en estas pantallas.
- Un negocio abierto por contacto. Eliminar un contacto elimina sus negocios y tareas; juntar dos contactos los pasa al contacto que se queda.
- El total de arriba de una columna suma los valores tal como están y los muestra en la moneda de su primer negocio; no convierte monedas.
