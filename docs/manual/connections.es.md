# Connections: canales, WhatsApp por QR y la salud del bot de IA

Connections reúne todos tus canales en una sola lista (WhatsApp por QR, WhatsApp oficial, Instagram, Messenger, sitio web, correo y otros) y te dice, de cada uno, si está conectado y quién responde en él: la IA o tu equipo. Está en el menú, en la sección **Channels**, como **Connections**. Un punto rojo en su ícono significa que algo necesita tu atención.

*También en: [English](connections.en.md) · [Português](connections.pt.md)*

## Antes de empezar

1. **Solo los administradores** ven Connections. Los agentes no ven la pantalla ni el punto rojo.
2. **La línea sobre el bot de IA** (quién responde en cada canal) necesita **Bot Personas** activado en tu cuenta (lo hace un administrador de la instalación en el Super Admin). Sin eso, la pantalla igual lista los canales y si están conectados, pero no el bot.
3. **Para conectar un número de WhatsApp por QR** la cuenta necesita **WhatsApp Sessions** activado en el Super Admin, y la instalación necesita tener configurado su gateway de WhatsApp (**Super Admin → Settings → WhatsApp Gateway**, con la dirección y la clave del gateway). Usa un **número dedicado** y ten a mano el teléfono con WhatsApp para escanear el código.
4. **Para que la IA responda en un canal** necesitas una persona (menú **Personas**, sección AI agent) y un bot de agente (**Settings → Bots**).

## ¿QR o API oficial?

| | WhatsApp por QR | WhatsApp API oficial (Meta) |
|---|---|---|
| Cómo se conecta | Escaneas un código QR con el teléfono, como al vincular un dispositivo en WhatsApp | Por Meta (WhatsApp Business "Quick setup with Meta" o WhatsApp Cloud), 360Dialog o Twilio |
| Dónde lo gestionas | **Settings → Integrations → WhatsApp Sessions** (también desde el botón **WhatsApp by QR code**) | En la propia bandeja, **Settings → Inboxes** (también desde el botón **WhatsApp official API**) |
| Qué tiene aquí | Campañas de Outreach, recordatorios de citas y mensajes de cita perdida, el seguimiento de la IA cuando el cliente se queda callado y la alerta cuando la sesión se cae | El menú **Campaigns** estándar. Fuera de la ventana de 24 horas tras el último mensaje del cliente, WhatsApp solo permite plantillas aprobadas, así que lo de la izquierda no corre en ella |

En la lista, el tipo aparece como "WhatsApp · QR code", "WhatsApp · Official API (Meta)" o "WhatsApp · 360dialog".

## Paso a paso

### 1. Lee la pantalla
- Arriba, una línea roja dice cuántos canales necesitan atención: "N channels need attention: customers there may be getting no answer."
- Los canales están agrupados en **WhatsApp** y **Other channels**, con los que necesitan atención primero.
- Cada fila muestra el nombre del canal, su tipo y número de teléfono, una etiqueta **Connected** o **Disconnected**, y una línea sobre el bot (paso 4). Haz clic en el nombre para abrir los ajustes de la bandeja.
- Un botón **Fix** aparece en las filas que necesitan atención (paso 5).
- La etiqueta **Disconnected** solo existe para los canales que pueden perder la conexión: WhatsApp por QR, WhatsApp configurado con el quick setup de Meta, Instagram, Messenger, TikTok y correo con Google o Microsoft. Los demás (sitio web, Telegram, SMS y así) siempre muestran Connected.

### 2. Conecta un número por QR
1. En **Connections**, pulsa **WhatsApp by QR code**. Se abre **WhatsApp Sessions**.
2. Pulsa **New session** y rellena:

| Campo | Qué es |
|---|---|
| Session name | De 3 a 50 caracteres: letras minúsculas, números y guiones (por ejemplo `sales-line`) |
| Inbox | Deja "Create a new inbox for this session (recommended)". Elige una bandeja existente solo para reutilizarla: su conexión se reapunta a esta sesión. Si encuentra una bandeja que parece ser el mismo número, ofrece **Reuse this inbox** |
| Answer with an agent bot | Solo aparece si tienes bots de agente. Déjalo activado y elige el **Agent bot** para que la IA responda en este número |

3. Pulsa **Create**. Se abre la ventana **Pair WhatsApp** con un código QR (primero "Preparing QR code…").
4. En el teléfono, abre WhatsApp → Settings → Linked devices → Link a device, y escanea el código.
5. Cuando veas "Number connected! The session is ready." pulsa **Close**.
6. Vuelve a **Connections** y revisa la fila: **Connected** y "AI answers as …" (paso 4).

La lista de sesiones muestra **Session**, **Status**, **Phone**, **Inbox** y **Actions**:

| Estado | Significado |
|---|---|
| Created, Initializing | Arrancando |
| Waiting for QR scan | Esperando que escanees |
| Authenticating | El escaneo fue aceptado |
| Connected | Funcionando |
| Disconnected | La sesión se cayó (paso 7) |
| Action required, Failed | La sesión necesita ayuda: pulsa **Pair** de nuevo |

| Botón | Qué hace |
|---|---|
| Pair | Muestra el código QR para escanear. Aparece mientras la sesión no está Connected. También es como se reconecta |
| Start | Inicia de nuevo una sesión Disconnected |
| Stop | Detiene una sesión Connected |
| Log out | Cierra la sesión del número |
| Basurero | Elimina la sesión (mira el paso 7 antes de usarlo) |

### 3. Conecta la API oficial de WhatsApp
En **Connections**, pulsa **WhatsApp official API**. Se abre la creación de una bandeja de WhatsApp en **Settings → Inboxes**, donde eliges el proveedor (WhatsApp Business, WhatsApp Cloud, Twilio o 360Dialog) y sigues las pantallas. Los pasos propios de Meta no se cubren aquí.

### 4. Mira si la IA está respondiendo
La línea bajo cada canal dice quién responde en él:

| Lo que lees | Significado |
|---|---|
| AI answers as … | Todo bien: el bot está activo y tiene una persona |
| No AI — your team answers | No hay bot en este canal. No es un fallo si es lo que quieres |
| Voice calls, answered by the voice agent | Un número de voz. Responde el agente de voz, no el bot de texto |
| The AI bot is on but has no persona, so it does not answer | **Problema** (rojo). La bandeja llama al bot pero no hay persona que responda |
| The AI bot's saved credentials are out of date, so it does not answer | **Problema** (rojo). El bot y la persona se guardaron con credenciales distintas |
| A persona is set, but the AI bot is not on this channel, so it does not answer | **Problema** (rojo). La persona existe pero la bandeja no llama al bot |

Activar el bot desde los ajustes propios de la bandeja no configura la persona. Hazlo siempre desde **Bot Personas → Channels**.

### 5. Arregla un canal
**Fix** te lleva adonde se resuelve el problema:
- **Problema del bot:** a **Bot Personas → Channels**. En la fila del canal elige la **Persona** y el **Agent bot**, activa **Bot active** y pulsa **Save**. Guardar conecta el bot a la bandeja y vuelve a escribir sus credenciales, lo que resuelve los tres problemas del paso 4. El botón Save solo funciona con una persona y un bot elegidos. Si dice que no hay bots de agente, crea uno en **Settings → Bots**.
- **WhatsApp por QR que se cayó:** a **WhatsApp Sessions** (paso 7).
- **Otro canal que se cayó:** a los ajustes de la bandeja, donde lo reconectas.

El basurero de una fila quita la ruta de la persona de ese canal.

### 6. El punto rojo en el menú
El punto rojo en el ícono de **Connections** aparece cuando algún canal está **Disconnected** o tiene uno de los tres problemas del bot. Se calcula al cargar la página, así que después de arreglar algo recarga la página o abre Connections. Solo lo ven los administradores.

### 7. Cuando una sesión QR se cae
El sistema revisa las sesiones cada 5 minutos. Cuando una sesión no está Connected en dos revisiones seguidas (así que tarda entre 5 y 10 minutos en notarlo, para evitar falsas alarmas cuando el gateway se reinicia), la bandeja se marca:
- el punto rojo, y **Disconnected** en la fila de Connections;
- un aviso en los ajustes de la bandeja: "This WhatsApp number is disconnected. Replies and follow-ups are not delivered until you scan the QR code again on the same connection." con el botón **Scan the QR code**;
- un correo a los administradores de la cuenta;
- los seguimientos de la IA se saltan esa bandeja, y las campañas de Outreach en ese número se pausan (mira el manual de Outreach).

Para reconectar:
1. Pulsa **Fix** en Connections (o **Scan the QR code** en los ajustes de la bandeja). Llegas a **WhatsApp Sessions**.
2. En la sesión de ese número pulsa **Pair** y escanea el código QR.
3. Cuando diga "Number connected! The session is ready." la alerta desaparece de inmediato.

**Reconecta siempre en la misma sesión.** Crear una sesión nueva para el mismo número hace una bandeja duplicada, sin las conversaciones ni el bot de antes. Si de verdad necesitas una sesión nueva, **New session** ofrece **Reuse this inbox** cuando encuentra la bandeja anterior.

Eliminar una sesión (basurero, luego **Delete**) quita la conexión con el gateway pero conserva la bandeja y sus conversaciones; el bot deja de responder ahí. Para recuperarla, crea una **New session** y reutiliza la bandeja anterior.

## Cuando algo falla o se detiene

| Lo que ves | Qué significa y qué hacer |
|---|---|
| "OpenWA gateway is not configured. Set the gateway URL and API key in Super Admin → Settings → WhatsApp Gateway." | La instalación todavía no tiene los datos del gateway. Pregunta a su administrador |
| "Could not reach the OpenWA gateway" | El gateway no respondió. Inténtalo de nuevo en un minuto; si persiste, avisa al administrador de la instalación |
| "Session name must be 3-50 characters, lowercase letters, numbers and hyphens only." | Corrige el **Session name** |
| "The selected inbox must be an API channel inbox." | Elegiste una bandeja que no se puede reutilizar. Deja "Create a new inbox for this session" |
| "Session not found for this account." | Esa sesión es de otra cuenta o ya no existe. Recarga la lista |
| "Bot route not created: persona not found in the bot layer." | La configuración automática busca una persona con un nombre fijo elegido por la instalación, y tu cuenta no tiene ninguna con ese nombre. El número se conectó pero el bot no responderá: ve a **Bot Personas → Channels** y define la persona, el bot y **Bot active** |
| "Bot route not created: Supabase env vars are missing. Add the route manually." o "Bot route creation failed. Add the route manually." | La misma solución: **Bot Personas → Channels** |
| El código QR se queda en "Preparing QR code…" | Espera unos segundos: sigue consultando solo. Si no aparece, cierra la ventana y pulsa **Pair** otra vez. Si el estado es Failed o Action required y persiste, avisa al administrador de la instalación |
| La fila dice Disconnected pero el teléfono está bien | El gateway perdió la sesión. Pulsa **Pair** y escanea de nuevo |
| "This inbox belongs to a Twilio voice route…" al guardar un canal | Esa bandeja es solo el registro de las llamadas de voz: las responde el agente de voz. No le pongas un bot de texto |
| Llegan mensajes pero la IA no responde | Lee la línea del bot en Connections (paso 4) y aplica **Fix** |
| Se conectó un número nuevo pero el bot está en silencio | La línea del bot muestra el problema. Haz el paso 5 |

## No incluido
- La pantalla no conecta Instagram, Messenger, sitio web ni correo: se crean en **Settings → Inboxes**. Connections solo los muestra y los arregla.
- Las sesiones QR nunca se reconectan solas: cuando WhatsApp corta el vínculo, alguien tiene que escanear el código de nuevo.
- El punto rojo y las líneas no son en vivo: se actualizan al cargar la página.
- Los agentes no reciben la alerta; solo los administradores (en la pantalla y por correo).
- Sin historial de mensajes ni métricas por canal en esta pantalla.
- El estado Connected no prueba que lleguen mensajes en los canales que no pueden informar una caída (sitio web, Telegram, SMS).
