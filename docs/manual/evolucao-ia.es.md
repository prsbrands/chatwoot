# AI evolution: la IA aprende de lo que responde tu equipo

Una vez al día, la IA lee las conversaciones que no pudo resolver sola y lo que tu equipo respondió, y propone cambios concretos en su base de conocimiento y en sus instrucciones. Nada cambia hasta que lo apliques. Está en el menú, en **AI agent → AI evolution**.

*También en: [English](evolucao-ia.en.md) · [Português](evolucao-ia.pt.md)*

## Antes de empezar

1. **AI Evolution activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, en las funciones de la cuenta, interruptor **AI Evolution**). Sin eso el ítem del menú no aparece.
2. **Solo los administradores** de la cuenta ven y usan AI evolution, porque aplicar una propuesta cambia la base de conocimiento y las instrucciones que la IA usa con todos los clientes.
3. **Una IA respondiendo tus bandejas.** Una *persona* de IA tiene que responder al menos una bandeja (AI agent → Personas, pestañas **Personas** y **Channels**). Las propuestas van a la base de conocimiento y a las instrucciones de esa persona.
4. **Algo de qué aprender.** La IA solo lee conversaciones que tengan al menos una de estas señales:

| Señal | Qué es | Qué enseña |
|---|---|---|
| Pasada al equipo, y una persona respondió | La IA pasó la conversación al equipo (la nota privada "Handoff · ...") y, después, una persona del equipo le escribió al cliente | La respuesta que la IA no sabía |
| Respuesta retenida por Jev | La misma nota de traspaso, con el borrador que Jev retuvo (necesita **Check before sending** de Jev activado) | Lo que la IA iba a decir mal y lo que el equipo mandó en su lugar |
| Caso abierto por la IA | Un caso que la IA abrió (necesita **Cases** activado) y que el equipo respondió por el asistente o resolvió con una nota en **What was done** | Lo que la IA no pudo resolver sola |

5. **Cuándo corre.** La ronda corre una vez al día, a las 3:00 a. m. hora de Panamá. Las propuestas nuevas aparecen después. Solo se leen las conversaciones quietas desde hace al menos 2 horas, con actividad en los últimos 14 días, y solo la parte que no se leyó antes: el mismo tramo nunca se paga dos veces.
6. **Costo.** La ronda usa el modelo normal de la persona (no el liviano) y cuenta en **AI usage** y en el tope mensual de IA de la cuenta. Una cuenta que llegó al tope se salta.
7. **Privacidad.** Los correos y teléfonos se quitan del texto antes de que vaya al modelo de IA.
8. **Números que conviene conocer.**

| Qué | Valor |
|---|---|
| Conversaciones leídas por cuenta al día | hasta 20 |
| Llamadas a la IA al día | una por persona, con todas sus conversaciones juntas |
| Propuestas guardadas por llamada | hasta 10 |
| Título / texto de una propuesta | hasta 120 / 2.000 caracteres |
| Evidencia guardada en una propuesta | las 10 conversaciones más recientes (el chip cuenta todas) |
| Una propuesta rechazada no se vuelve a proponer | durante 90 días |
| Propuestas listadas por pestaña | hasta 200 |
| Progress | las últimas 12 semanas |

## Paso a paso

### 1. Abre las propuestas
**AI agent → AI evolution**, pestaña **Proposals**. Un número en el ítem del menú muestra cuántas propuestas esperan revisión (se actualiza cada minuto).

- **To review / Applied / Rejected** eligen el grupo. Las de revisar vienen con más evidencia primero.
- **All / New knowledge / Knowledge fix / Instruction** filtran por tipo.
- Cuando no hay nada, la pantalla dice "Nothing to review. Proposals appear after the daily round, when the AI handed a conversation to the team and the team answered."

### 2. Lee una propuesta
Cada tarjeta muestra:

- El **tipo**, **dónde** iría y un chip con el número de conversaciones que la enseñaron ("3 conversations"). Aparece **edited** si alguien cambió el texto.
- **Why:** una frase con el motivo.
- La **evidencia**: por cada conversación, **Customer:** lo que dijo el cliente, **Team:** lo que respondió tu equipo y el enlace **Open conversation #id**.

| Tipo | Qué hace | Adónde va |
|---|---|---|
| New knowledge | Agrega una sección corta con un dato que dio el equipo (un precio, un plazo, una política, una zona atendida) | El documento de conocimiento que sugiere la IA, o el documento **Aprendizados da IA** cuando ninguno encaja |
| Knowledge fix | Reemplaza una frase de la base de conocimiento que el equipo contradijo o completó. La tarjeta muestra el texto a reemplazar, tachado, bajo **Replaces this text of the knowledge base** | El documento donde está ese texto |
| Instruction | Una frase sobre cómo debe comportarse la IA (por ejemplo, no prometer fecha de entrega). Nunca es un dato ni un precio | Las instrucciones de la persona |

La IA propone solo lo que tu equipo dijo o hizo, nunca un precio, fecha o política inventados. Si cinco clientes preguntaron lo mismo, ves una propuesta con cinco conversaciones de evidencia, no cinco propuestas.

### 3. Edita y aplica
Antes de aplicar puedes cambiar el texto:

- **Title** (no se muestra en Instruction).
- **Text for the knowledge base** (New knowledge y Knowledge fix) o **Instruction for the AI** (hasta 2.000 caracteres).

Pulsa **Apply**. El mensaje "Applied" lo confirma, y la propuesta pasa a **Applied**, con quién la aplicó y la fecha. La IA usa el cambio desde el próximo mensaje; no hace falta ningún despliegue. Qué pasa en cada tipo:

- **New knowledge:** se agrega una sección `### Título` seguida del texto al final del documento. En **Aprendizados da IA** (un documento que crea el sistema, con ese nombre en cualquier idioma, vinculado a la persona la primera vez) encuentras estas secciones en AI agent → Personas → **Knowledge base**.
- **Knowledge fix:** el texto mostrado tachado se reemplaza por el texto nuevo.
- **Instruction:** se agrega una línea `- instrucción` al final de las instrucciones de la persona, bajo un encabezado `## Aprendizados` (creado la primera vez).

### 4. Rechaza
Pulsa **Reject**, escribe por qué en el campo "Why not? The AI will not propose it again." (opcional pero útil) y pulsa **Reject** de nuevo. **Cancel** desiste. La propuesta pasa a **Rejected** con tu motivo, y se le indica a la IA que no la proponga de nuevo durante 90 días.

### 5. Deshaz
En **Applied**, **Undo** devuelve la base de conocimiento o las instrucciones a como estaban antes, y la propuesta vuelve a **To review** ("Undone: back to review"). Solo funciona si nadie editó ese texto después de aplicar la propuesta; si no, se niega, para no borrar la edición de otra persona.

### 6. Sigue el progreso
Pestaña **Progress**: las últimas 12 semanas, la más reciente primero, de las conversaciones en bandejas con la IA.

| Columna | Qué cuenta |
|---|---|
| Week of | El lunes de la semana |
| Conversations | Conversaciones en las que el cliente escribió |
| Handed to the team | Porcentaje de esas que se pasaron al equipo, con una barra |
| Replies held by Jev | Respuestas que Jev retuvo antes de enviar |
| Cases opened by the AI | Casos que la IA abrió |
| Proposals applied | Propuestas que aplicaste esa semana (resaltado cuando es mayor que cero) |

Muestra la tendencia junto a los cambios que aplicaste; no prueba que un cambio causó una mejora.

## Cuando algo falla o se detiene

| Qué ves | Qué hacer |
|---|---|
| "Nothing to review ..." por días | Revisa: **AI Evolution** activado; una persona respondiendo una bandeja; conversaciones pasadas al equipo y respondidas por una persona (y quietas por 2 horas); la cuenta no está en el tope mensual de IA; la ronda diaria está corriendo (pregunta al administrador de la instalación) |
| "the text to replace is no longer in the knowledge base" | Alguien editó la base de conocimiento. Cámbiala a mano en AI agent → Personas → **Knowledge base** y luego **Reject** la propuesta |
| "the knowledge document no longer exists" / "the persona no longer exists" | El documento o la persona se borraron; **Reject** la propuesta |
| "the text changed since it was applied; undo it by hand" | El texto se editó después de aplicar; arréglalo a mano en Personas |
| "only pending suggestions can be applied" | Otra persona ya la decidió; recarga la página |
| "Could not save. Try again." | Inténtalo de nuevo; revisa que el título y el texto estén completos y dentro de los límites |
| Una propuesta dice "in "Aprendizados da IA"" | Es el documento compartido para conocimiento nuevo; no está en tu idioma porque lo crea el sistema |

## Buenas prácticas
- Lee la evidencia antes de aplicar: una conversación rara no es una política. Prefiere propuestas con varias conversaciones.
- Edita el texto a tu estilo y quita todo lo que sea específico de un solo cliente.
- Rechaza con un motivo corto; le enseña a la IA lo que no quieres.
- Después de aplicar, mira **Progress** en las semanas siguientes.

## No incluido
- No aplica nada por sí sola: cada cambio necesita tu **Apply**.
- No aprende de las ediciones que tu equipo haga a las respuestas de la IA, solo de lo que el equipo responde cuando la IA traspasa, de las respuestas retenidas y de los casos.
- Una propuesta rechazada no se puede reabrir (solo las aplicadas se pueden deshacer).
- No hay filtro por persona en la pantalla.
- No juzga si un cambio aplicado mejoró las cosas; **Progress** muestra la tendencia.
