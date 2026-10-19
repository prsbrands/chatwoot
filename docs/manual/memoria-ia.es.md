# AI memory: lo que la IA recuerda de cada cliente

AI memory es un resumen corto y una lista de datos sobre cada cliente que la IA mantiene al día sola después de las conversaciones, y que lee antes de responder, en cualquier canal. Puedes leerla, corregirla y completarla. Está en el bloque **AI memory** del panel derecho de cualquier conversación, y en la pestaña **AI memory** del contacto (Contacts → abre un contacto).

*También en: [English](memoria-ia.en.md) · [Português](memoria-ia.pt.md)*

## Antes de empezar

1. **No hay ningún interruptor que activar.** El panel es parte de la instalación y está disponible para todas las cuentas. La IA solo lo completa para los clientes que hablaron por una bandeja que responde un bot de IA.
2. **Quién puede usarla.** Agentes y administradores ven y editan la memoria de cualquier cliente.
3. **Una IA respondiendo la bandeja.** Una *persona* de IA tiene que responder al menos una bandeja (AI agent → Personas, pestaña **Channels**). Además, el administrador de la instalación tiene que mantener publicado el workflow "CortexGen Memória" en n8n: es el que escribe la memoria.
4. **Cuándo escribe la IA.** Una conversación se lee cuando el último mensaje del cliente tiene al menos 30 minutos (por eso la memoria aparece unos 30 a 40 minutos después del fin de una conversación, un poco más si hay muchos clientes esperando), la conversación tuvo actividad en los últimos 7 días y tiene mensajes del cliente que no se leyeron antes. Varias conversaciones del mismo cliente se leen una por vez, y solo se lee la parte nueva.
5. **Costo.** La IA usa el modelo liviano de la persona (o el modelo normal de la persona si no tiene uno liviano). Cuenta en **AI usage**, como **Customer memory**, y en el tope mensual de IA de la cuenta. Una cuenta que llegó al tope se salta, y su memoria deja de actualizarse hasta el mes siguiente o hasta que se suba el tope.
6. **Números que conviene conocer.**

| Qué | Valor |
|---|---|
| El workflow corre | cada 10 minutos |
| Clientes actualizados por corrida | hasta 5 |
| Mensajes leídos por ronda | hasta 40 nuevos, más 6 anteriores para contexto |
| Resumen | hasta 1.500 caracteres (la IA escribe hasta 5 frases) |
| Cada dato | hasta 300 caracteres (la IA los escribe cortos, de unas 15 palabras como máximo) |
| Datos nuevos por ronda | hasta 10 |
| Datos por cliente | cuando el total pasa de 30 (los tuyos incluidos), la IA borra sus datos más antiguos que no estén fijados |
| Lo que la IA lee antes de responder | el resumen y los datos, hasta 1.500 caracteres en total |
| Reintento tras una ronda fallida | después de 1 hora |

## Paso a paso

### 1. Abre la memoria de un cliente
- **En una conversación:** en el panel derecho, abre el bloque **AI memory** (por defecto viene justo después del bloque del negocio; la flecha lo abre y lo cierra).
- **En un contacto:** Contacts → abre el contacto → pestaña **AI memory**.

La memoria pertenece al contacto y es la misma en todos los canales. Si la misma persona son dos contactos distintos (por ejemplo un número de WhatsApp y un correo), cada uno tiene su propia memoria hasta que unas los contactos.

Si todavía no se escribió nada, el panel dice "Nothing remembered yet. The AI fills this in when a conversation has been quiet for 30 minutes, and reads it before answering in any channel."

### 2. Léela
- **Summary:** cómo está la situación ahora, en pocas frases: qué pide el cliente en este momento, qué se acordó, qué está pendiente. Debajo, "Updated by the AI on ..." da la fecha de la última actualización de la IA.
- **Facts:** una línea corta cada uno sobre lo que sigue siendo cierto del cliente: quién es, su negocio, presupuesto, decisiones, objeciones, preferencias (horario, canal, tono), qué compró y compromisos con fecha o responsable. Un dato marcado **team** lo escribió o corrigió una persona. Una chincheta de color marca un dato fijado. Los fijados van primero, luego los más antiguos.

### 3. Agrega un dato
Escríbelo en el campo **Add a fact about this customer** y pulsa Enter, o pulsa el botón **+** (**Add fact**). Un dato que tú escribes queda marcado **team**.

### 4. Corrige o borra un dato
Pasa el mouse sobre el dato:

- El lápiz (**Edit fact**) permite reescribirlo; pulsa Enter o **Save** (**Cancel** desiste). Un dato que editas pasa a **team**.
- El basurero (**Delete fact**) lo borra enseguida, sin pedir confirmación.

### 5. Fija un dato
Pulsa la chincheta junto al dato (**Pin: the AI reads it first and never changes it**). Para deshacer, púlsala otra vez (**Unpin**). Úsalo para lo que nunca debe olvidarse ni cambiarse, como "no llamar antes de las 18 h".

### 6. Edita el resumen
Pulsa el lápiz **Edit summary**, reescríbelo (hasta 1.500 caracteres) y pulsa **Save** (o **Cancel**). La IA recibe tu texto en la próxima ronda y conserva lo que sigue siendo cierto, pero el resumen no queda bloqueado: la IA puede reescribirlo después. Para algo que debe quedar, usa un dato fijado.

### 7. Qué puede y qué no puede cambiar la IA

| Elemento | Escrito por | ¿La IA lo puede cambiar o borrar? |
|---|---|---|
| Dato sin marca, no fijado | La IA | Sí: lo cambia cuando el cliente lo corrige y lo borra cuando ya no es cierto o el resumen ya lo cubre |
| Dato marcado **team** | Una persona (escrito o editado) | No |
| Dato fijado | La IA o una persona | No: la IA lo lee primero y nunca lo cambia |
| Summary | La IA | Lo actualiza en cada ronda; si lo editas, conserva tu texto pero puede reescribirlo después |

### 8. Cómo usa la IA la memoria
Antes de cada respuesta, la IA recibe una sección "CUSTOMER MEMORY" con el resumen y los datos: primero los fijados, luego los más nuevos, hasta 1.500 caracteres en total (un resumen largo deja menos lugar para los datos, así que mantenlo corto). La IA la usa para no volver a preguntar lo que el cliente ya dijo y para continuar donde van las cosas. Lo que el cliente escribe ahora siempre vale más que la memoria, y la IA nunca dice que guarda notas sobre el cliente. Si la memoria no se puede leer, la IA simplemente responde sin ella.

## Qué escribe la IA y qué nunca escribe
- **Escribe** lo que el cliente dijo, decidió o prometió: quién es, su negocio, presupuesto, decisiones, objeciones, preferencias, qué compró, contexto personal que compartió y compromisos abiertos con fecha o responsable (se quitan cuando se cumplen).
- **No escribe** lo que la empresa o la IA hizo o dijo (que se envió un precio, una cotización o un enlace, quién lo atendió, qué respondió el equipo), saludos y charla, los precios y reglas de la propia empresa, suposiciones, estados del momento ("está en línea ahora"), números de tarjeta, contraseñas o documentos.
- **Cada información va en un solo lugar:** lo que es solo la solicitud o el estado actual va en el resumen; lo que sigue siendo cierto va en un dato. Un dato que el resumen ya cubre se quita, y un dato que ya está en la memoria con otras palabras no se agrega de nuevo.

## Contactos unidos y borrados
- **Merge** (Contacts → abre un contacto → pestaña **Merge**): los datos de ambos contactos quedan con el contacto que permanece, los dos resúmenes se ponen uno después del otro y la IA vuelve a leer las conversaciones para completar lo que falte.
- **Borrar un contacto** borra su memoria.

## Cuando algo falla o se ve raro

| Qué ves | Qué hacer |
|---|---|
| "Nothing remembered yet ..." | Es normal en un cliente nuevo. Espera a que la conversación lleve 30 minutos quieta. Si nunca se completa: la bandeja no tiene una IA respondiéndola, la conversación tiene más de 7 días, la cuenta está en el tope mensual de IA, o el workflow "CortexGen Memória" está detenido (pregunta al administrador de la instalación) |
| La memoria no se actualiza | Las mismas revisiones; recuerda también que solo los mensajes nuevos del cliente inician una ronda nueva |
| "Could not save the AI memory. Try again." | Inténtalo de nuevo; un dato puede tener hasta 300 caracteres y el resumen hasta 1.500 |
| La IA vuelve a preguntar lo que el cliente ya dijo | Agrega el dato tú mismo y fíjalo |
| Un dato equivocado | Edítalo (pasa a **team**, y la IA no lo vuelve a tocar) o bórralo |
| Un dato que es solo una acción de la empresa, o que repite el resumen | Bórralo; la IA debería evitarlo desde el último ajuste, y avisa al administrador de la instalación si sigue pasando |
| La memoria parece muy larga | Mantén el resumen corto: resumen y datos juntos llegan a la IA solo hasta 1.500 caracteres, y lo que sobra queda fuera |

## No incluido
- Sin memoria para clientes que nunca hablaron por una bandeja con un bot de IA.
- Sin vista de todas las memorias a la vez ni búsqueda por memoria: es un cliente por vez.
- Sin historial de los cambios (quién cambió qué dato); solo el estado actual.
- Sin confirmación antes de borrar un dato, y sin forma de recuperarlo.
- La IA no guarda documentos, contraseñas ni números de tarjeta.
