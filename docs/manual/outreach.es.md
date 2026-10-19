# Outreach: campañas en tu número de WhatsApp por QR

Outreach envía un mensaje a una lista de personas desde tu número de WhatsApp por QR, a un ritmo que protege el número para que no lo bloqueen. Está en el menú, en **CRM → Outreach**.

*También en: [English](outreach.en.md) · [Português](outreach.pt.md)*

## Antes de empezar

1. **Un número de WhatsApp por QR conectado.** Tiene que estar conectado por QR en **Connections** (no la API oficial de WhatsApp). Si la sesión se desconecta, las campañas se pausan solas.
2. **La zona horaria del número.** Abre la bandeja de ese número en Settings → Inboxes → Business hours y elige su zona horaria. Las campañas no arrancan en una bandeja en UTC, porque el horario de envío quedaría mal.
3. **Outreach activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin). Solo los administradores de la cuenta ven y usan Outreach.
4. **Edad del número.** Un número nuevo puede enviar poco: 20 mensajes por día los primeros 3 días, 50 hasta el día 7, 100 hasta el día 14 y 200 después. La campaña nunca pasa de ese límite, aunque configures uno mayor.

## Paso a paso

### 1. Crea la campaña
**Outreach → New campaign.** Ponle un nombre, elige el número y escribe el primer mensaje. Todo lo demás se ajusta en la página de la campaña, mientras sigue como **Draft** (borrador).

### 2. Escribe el mensaje
- **Versiones:** hasta 3 textos. Se alternan de una persona a la siguiente, para que no todos reciban las mismas palabras. Usa **Add another version**.
- **Variables:** `{name}` (primer nombre), `{full_name}`, `{company}` y cualquier columna de tu archivo, escrita en minúsculas y sin tildes (la columna "Ciudad" pasa a ser `{ciudad}`). Quien no tenga el dato que una versión necesita queda fuera de la campaña, así nadie recibe "Hola {name}".
- **Opciones al azar:** `{Hola|Buenas|Qué tal}` elige una de las palabras cada vez.
- **Burbujas:** una línea en blanco empieza un nuevo mensaje de WhatsApp (hasta 4). Entre burbujas el número muestra "escribiendo…".
- **Cold list (lista fría):** márcala cuando las personas nunca hablaron contigo. Entonces la campaña usa solo la mitad del límite diario del número.
- **Opt-out line (línea de salida):** texto que se agrega al final de cada mensaje, por ejemplo "Responde PARAR para no recibir más mensajes." Quien responda con una palabra de parada queda bloqueado y no vuelve a recibir campañas.

Pulsa **Save**. Si la campaña estaba lista, vuelve a borrador y tienes que preparar la lista otra vez.

### 3. Define el ritmo
Todo lo de aquí solo puede hacer la campaña más lenta que los límites del propio número, nunca más rápida.

| Campo | Qué hace | Por defecto |
|---|---|---|
| Starts / Ends at (hour) | Ventana de envío, en la zona horaria del número | 8 a 20 |
| Days | Días de la semana permitidos | lun a sáb |
| Gap between messages | Segundos al azar entre los dos valores, nunca menos de 15 | 20 a 45 |
| Per hour, at most | Tope por hora de esta campaña | 30 |
| Per day, at most | Tope por día de esta campaña (vacío: el límite del número) | vacío |
| Messages before a break | Tras esa cantidad de mensajes la campaña descansa | 10 |
| Break (min) | Descanso al azar entre los dos valores | 5 a 15 |

Una campaña que llega a un límite no falla: espera y sigue en la próxima ventana.

### 4. Define la lista
Elige **Spreadsheet** (planilla) o **CRM contacts** y pulsa **Use this list**. Usar otra lista reemplaza la anterior.

**Spreadsheet.** CSV, XLSX u ODS, hasta 10.000 filas, con los títulos de las columnas en la primera fila. (Los archivos XLS antiguos: guárdalos primero como XLSX.)
- Elige el archivo. Se muestran las primeras filas.
- Indica qué columna es el **teléfono** (obligatorio), el **nombre** y la **empresa**. Outreach las adivina por los títulos.
- **Country code (código de país):** se agrega a los números escritos sin él (507 por defecto). Un número con "+" o "00" se usa tal cual. Un número largo sin código de país se rechaza en vez de adivinarse.
- Las demás columnas se pueden usar como variables en el mensaje.
- Las personas del archivo no se vuelven contactos hasta que respondan. Una lista fría no llena tu CRM.

**CRM contacts.** Elige una etiqueta y/o una bandeja. Los contactos sin teléfono aparecen como excluidos.

### 5. Revisa y empieza
1. **Send a test to yourself:** escribe tu número y pulsa **Send test**. Recibes la primera versión, con los datos de la primera persona de la lista. No cuenta en la campaña.
2. **Prepare the list.** Outreach revisa a todos y muestra cuántos **recibirán el mensaje** y cuántos **quedan fuera y por qué** (tabla de abajo).
3. **Start sending.** La campaña empieza de inmediato.

### 6. Sigue, pausa o cancela
En la página de la campaña:
- **Pause** se detiene después del mensaje que se está enviando. **Resume** continúa.
- **Cancel campaign** detiene para siempre; las personas que seguían esperando se cancelan.
- Los resultados se actualizan solos: **Sent**, **Replied**, **Waiting**, **Failed**, **Asked to stop** y **Left out**, con la lista de personas y un filtro por estado.
- La tasa de respuesta cuenta a quienes respondieron entre quienes recibieron el mensaje. Una respuesta solo cuenta para la campaña durante las 72 horas siguientes al envío.

## Quién queda fuera (y por qué)
La revisión se hace al preparar la lista **y de nuevo justo antes de cada mensaje**, porque alguien puede haber pedido parar en el medio.

| Motivo | Significado |
|---|---|
| Asked to stop receiving messages | El contacto está bloqueado |
| In the exclusion list | Agregado en Outreach → Exclusion list |
| No phone number / Not in a valid format | El número no se puede usar |
| Same number as another person on the list | Solo el primero recibe |
| Already waiting in another campaign | Una campaña a la vez por persona |
| Received a campaign in the last 30 days | Evita insistir |
| Open conversation with your team | Las campañas nunca interrumpen una conversación en curso |
| Missing data the message uses | Por ejemplo, `{name}` para alguien sin nombre |

## Lista de exclusión
**Outreach → Exclusion list.** Números que ninguna campaña tocará nunca (tu contador, un competidor, un cliente al que solo llamas). Pega los números, uno por línea o separados por comas. No es lo mismo que alguien pedir parar: las personas de esta lista **se siguen atendiendo normalmente** si te escriben.

## Qué pasa cuando alguien responde
La respuesta llega a tu bandeja como cualquier otro mensaje, y el bot del número responde como siempre. La campaña marca a la persona como **Replied**. Si la persona nunca te había escrito, la conversación solo aparece en tu bandeja cuando responde; antes no hay nada en la lista de Conversations.

## Cuando una campaña se pausa sola
El menú muestra un número rojo y la campaña explica el motivo:
- **The WhatsApp session of the number is disconnected:** reconecta el número en Connections y pulsa **Resume**.
- **Three sends in a row failed:** revisa el número y la conexión, y pulsa **Resume**. A quienes falló el envío no se les reenvía automáticamente.
- **The number has no WhatsApp session:** se quitó la conexión; vuelve a conectarla.

Si **Start sending** dice que la bandeja necesita una zona horaria, defínela como se explica arriba. Si dice que nadie está esperando recibir, prepara la lista otra vez.

## Buenas prácticas para proteger tu número
- Empieza poco con un número nuevo y deja que actúen los límites por edad.
- Prefiere a quienes ya te conocen. Para listas frías, marca **Cold list**, escribe un mensaje corto que diga quién eres y usa la línea de salida.
- Usa 2 o 3 versiones del texto y opciones al azar, y evita enlaces en el primer mensaje.
- Mantén los intervalos y descansos por defecto. No lances varias campañas grandes en el mismo número el mismo día.
- Mira **Asked to stop** y **Failed**. Muchos de cualquiera de los dos indican que la lista o el mensaje necesitan trabajo.

## No incluido
- Sin marcas de "entregado" ni "leído" (WhatsApp por QR no las informa).
- Un número por campaña, sin rotación entre números.
- Sin campañas por la API oficial de WhatsApp ni SMS aquí; el menú **Campaigns** estándar las mantiene.
- Sin seguimiento automático para quienes no respondieron.
