# Cobros en línea y suscripciones

Deja que los clientes paguen facturas en línea, completas o en parte, y cobra planes mensuales o anuales de forma automática. El pago queda registrado, la factura se actualiza y el recibo se envía sin que nadie de tu equipo toque nada. Los proveedores se conectan en **CRM → Catalog → Company & payments → Online payments**, y las suscripciones están en el menú, en **CRM → Subscriptions**.

*También en: [English](comercial-cobranca.en.md) · [Português](comercial-cobranca.pt.md)*

*Módulo Commerce: [Catálogo y empresa](comercial-catalogo.es.md) · [Cotizaciones y facturas](comercial-documentos.es.md) · [Página pública del catálogo](comercial-vitrine.es.md)*

## Antes de empezar

1. **Commerce activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, marcando **Commerce** en las funciones de la cuenta).
2. **Una cuenta propia en el proveedor.** El dinero va directo a tu cuenta allí.

| Proveedor | Cuenta | Monedas | Qué usa el cliente | Qué pegas en el sistema |
|---|---|---|---|---|
| Stripe | Una cuenta de Stripe | USD, EUR, BRL | La página de pago alojada por Stripe | La secret key |
| Mercado Pago | Solo Mercado Pago **Brasil** | BRL | Tarjeta, Pix, boleto o saldo de Mercado Pago, en la página de Mercado Pago | El Access token |
| Yappy | Yappy Comercial (Botón de Pago) | USD | Aprobar el pago en el app de Yappy | Merchant ID, Secret key y, si hace falta, el dominio |

3. **Prueba primero en modo de prueba.** Todo proveedor se puede conectar como **Test mode** y después pasar a **Live** con las llaves reales (**Change key**).
4. **Una forma de pago vinculada al proveedor** (paso 2 más abajo) y **que siga marcada en la factura**.
5. **La moneda de la factura.** Al cliente solo se le ofrecen los proveedores que la aceptan: una factura en BRL muestra Mercado Pago y Stripe, una en USD muestra Stripe y Yappy, una en EUR muestra Stripe.
6. **La dirección pública de la instalación.** Los proveedores confirman los pagos llamando a esa dirección. Si tu instalación no es alcanzable desde internet, las confirmaciones nunca llegan.
7. **Quién puede hacer qué.** Los administradores conectan y desactivan proveedores y cancelan suscripciones. Todo el equipo crea suscripciones y envía su enlace.

## Paso a paso

### 1. Conecta un proveedor
**Company & payments → Online payments**. Cada proveedor tiene su propia tarjeta. Pulsa **Connect**, elige el **Environment** (**Test mode** o **Live**), completa las credenciales y pulsa **Connect** otra vez. Verás "Stripe connected." (o el nombre del proveedor). La tarjeta pasa a mostrar **Active**, "Test mode · key …1a2b" (solo se muestran los 4 últimos caracteres) y las monedas.

- **Stripe.** En el Dashboard de Stripe, Developers, API keys, copia la **secret key** (no la publishable) o una llave restringida con permiso de escritura en Checkout Sessions y Webhook Endpoints. Debe coincidir con el ambiente: `sk_test_` o `rk_test_` en Test mode, `sk_live_` o `rk_live_` en Live. El webhook de pagos se crea solo; no hay nada que registrar.
- **Mercado Pago.** En Mercado Pago Developers, Your integrations, tu aplicación, Production credentials (o las de prueba), copia el **Access token** (no la Public key). Solo se aceptan cuentas de Mercado Pago Brasil. Un token que empieza con `TEST-` abre el checkout de prueba.
  - **Webhook secret signature (opcional):** si defines un secreto en Your integrations, Webhooks, pégalo aquí para una verificación extra. Sin él, cada aviso se confirma igual leyendo el pago en Mercado Pago.
  - **Para las suscripciones este paso es obligatorio.** La tarjeta muestra la **Webhook URL**. En Mercado Pago, Your integrations, tu aplicación, Webhooks, **modo producción**, registra esa dirección con los eventos **Payments** y **Plans and subscriptions**. Sin eso, los cobros de las suscripciones no se registran aquí.
- **Yappy.** En Yappy Comercial, Botón de Pago, copia el **Merchant ID** y la **Secret key**, y registra la dirección de la instalación (o el dominio que escribas en **Domain registered in Yappy (optional)**) como dominio de pago. Solo USD.

La llave se guarda cifrada y no se vuelve a mostrar. **Change key** la reemplaza. **Disable** pausa el proveedor (sus formas de pago dejan de mostrar el botón de pagar) y **Enable** lo devuelve; los pagos ya hechos quedan en el historial.

### 2. Vincula una forma de pago al proveedor
**Company & payments → Payment methods**, crea o edita una forma y elige el proveedor en **Online charge**. La lista pasa a decir "Online with Stripe". Si el proveedor está conectado pero ninguna forma activa lo usa, su tarjeta avisa "No active payment method uses Stripe yet, so invoices show no Pay button…".

En cada factura, la forma debe seguir marcada en "Payment methods shown on this document" (con la marca "(Pay button)"). El nombre de la forma es el texto del botón, "Pay with …", así que ponle un nombre claro, como "Card" o "Yappy".

### 3. Qué hace el cliente
En el enlace de la factura (o en el botón "Pay online" del correo) el cliente encuentra **Pay online**, con **Amount to pay** ya completado con el saldo y un botón por forma de pago.
- El cliente puede pagar **menos que el saldo**: al menos 1 unidad de la moneda, o todo el saldo cuando es menor que 1.
- **Stripe y Mercado Pago:** el botón abre la página del proveedor; después de pagar, el cliente vuelve a la factura. La página dice que el pago se está confirmando, se actualiza sola y después agradece al cliente y anuncia el recibo.
- **Yappy:** el cliente escribe el **celular Yappy** de 8 dígitos y pulsa el botón. La página pide aceptar la solicitud en el app de Yappy y se actualiza sola cuando el pago se confirma. Pasados 10 minutos sin confirmación, la página dice que la confirmación puede tardar unos minutos más y ofrece un enlace para volver a la factura.
- Si el pago es rechazado o la solicitud vence, la página lo dice y el cliente puede intentar de nuevo. Si el pago ni siquiera puede empezar (monto fuera de rango, celular equivocado, proveedor que rechazó), la página pide revisar el monto e intentar de nuevo.

Los textos de la página están en el idioma del documento.

### 4. Qué pasa de tu lado
Solo vale una confirmación del proveedor (el aviso que él envía, o la respuesta cuando el sistema le pregunta). Que el cliente vuelva a la página no prueba nada por sí solo. Cuando llega:
- La factura recibe el pago (con la marca "Online") y pasa a **Partially paid** o **Paid**.
- El recibo `REC-…` se emite y se envía por la conversación y por el último correo usado en la factura.
- Si la factura tiene una conversación, una nota privada dice "Online payment received: …" con el monto, la factura, la forma y el recibo.
- Cuando la factura queda **Paid**, el negocio abierto del contacto pasa a Won.
- El mismo aviso llegando dos veces nunca paga dos veces.

### 5. Demoras y la red de seguridad
- Cada 5 minutos el sistema le pregunta al proveedor por los intentos que no tuvieron respuesta (pasados 2 minutos) y aplica lo que encuentra. Un intento que sigue sin pagarse después de 24 horas vence. Un cliente que vuelve de la página del proveedor también dispara una consulta.
- Yappy no se puede consultar: su confirmación solo llega como aviso, y un intento sin aviso vence a las 24 horas.
- Las devoluciones se hacen en el panel del proveedor. El sistema no las registra, y un pago que llegó en línea no se puede quitar de la factura.

### 6. Crea una suscripción
Una suscripción necesita un **plan**: un ítem del catálogo con **Billing** en Monthly plan o Yearly plan (mira [Catálogo y empresa](comercial-catalogo.es.md)).

**CRM → Subscriptions → New subscription**:
- **Customer:** busca y elige un contacto.
- **Plan:** los planes disponibles, cada uno con su precio.
- **Quantity:** empieza en 1; el cobro es el precio por la cantidad.
- **Payment method:** solo las formas activas cobradas en línea por Stripe, Mercado Pago o Yappy. Stripe (USD, EUR, BRL) y Mercado Pago (BRL) cobran de forma automática. Yappy (USD) no tiene débito automático, así que cada factura de renovación se envía 3 días antes del vencimiento con el enlace de pago.

Pulsa **Create**. El precio, la moneda y el ciclo se copian del plan, así que los cambios posteriores en el catálogo no afectan a esta suscripción. Los detalles se abren solos.

### 7. Envía el enlace al cliente
Una suscripción nueva está **Awaiting customer** y muestra su enlace. Puedes **Copy link** y enviarlo como prefieras, o elegir la conversación y pulsar **Send link to this conversation**. Esa conversación pasa a ser también la que se usa para los recibos y avisos de la suscripción. También se usa el correo del cliente en el contacto, cuando es válido.

El cliente abre la página "Subscription · nombre del plan" con el precio por mes o por año y un botón **Subscribe with …**:
- **Stripe:** abre la página de pago de Stripe. El primer cobro ocurre de inmediato.
- **Mercado Pago:** la página pide primero el **Email of your Mercado Pago account** y después abre Mercado Pago para autorizar la suscripción.
- **Yappy:** abre la factura del primer ciclo, con vencimiento hoy, y el cliente la paga con el celular Yappy, como cualquier factura.

Cuando el cliente vuelve, la página dice que la suscripción fue recibida y que el recibo del primer pago está en camino.

### 8. Cómo se cobra cada ciclo

| Proveedor | Cómo cobra | Qué recibes en el sistema |
|---|---|---|
| Stripe | Automáticamente, cada mes o año | Una factura pagada del período y el recibo, enviado. Si un cobro es rechazado, la suscripción pasa a **Past due** con una nota privada, y Stripe lo intenta de nuevo |
| Mercado Pago | Automáticamente, con la tarjeta autorizada por el cliente. Necesita el webhook registrado en el paso 1 | Lo mismo: factura pagada y recibo, o **Past due** cuando es rechazado |
| Yappy | Asistido: 3 días antes del fin del período se crea la factura del próximo ciclo, con vencimiento al fin del período, y su enlace sale por la conversación de la suscripción y por el correo del cliente. El día del vencimiento sale un recordatorio por chat | Pagar esa factura renueva la suscripción. Sin pagar 5 días después del vencimiento, la suscripción pasa a **Past due** con una nota privada |

La suscripción pasa a **Active** cuando se paga su primer ciclo. Una suscripción **Past due** vuelve a **Active** cuando se paga una renovación.

### 9. Sigue y cancela
- La lista muestra el plan, el cliente, "Renews on {date}" o "Ends on {date}", el precio por mes o por año y el estado: **Awaiting customer**, **Active**, **Past due** o **Canceled**. Filtra por estado y busca por plan o cliente.
- Haz clic en una suscripción para ver sus **Invoices**: número, período, recibos, total y estado. Haz clic en una factura para abrirla. También están en **Quotes & invoices**.
- **Cancel at period end** (administradores): el cliente conserva lo que pagó y no se cobra un nuevo ciclo. En Mercado Pago el cobro se detiene de inmediato y la suscripción sigue **Active** aquí hasta que termina el período pagado. **Cancel now**: termina la suscripción de inmediato y anula la factura de renovación abierta. Ambos piden un segundo clic ("Click again to confirm").
- Una suscripción que sigue **Awaiting customer** siempre se cancela de inmediato.
- Si un cliente pide cancelar por chat, un administrador lo hace aquí. La IA no cancela suscripciones.

### 10. Cuando vende el asistente de IA
Si el asistente de IA de la cuenta vende desde el catálogo y un cliente dice qué plan quiere, el asistente crea la suscripción (o reutiliza la pendiente de ese plan) y envía el enlace en la conversación. Para eso, el plan debe estar **Available** y debe haber una forma de pago activa cuyo proveedor cobre suscripciones en la moneda del plan.

## Cuando algo falla o no aparece

| Qué ves | Qué hacer |
|---|---|
| "The secret key does not match the sandbox environment" (o production) | La llave y el ambiente no coinciden: **Test mode** es "sandbox" y lleva `sk_test_` o `rk_test_`; **Live** es "production" y lleva `sk_live_` o `rk_live_` |
| Un mensaje de Stripe al conectar | La llave está equivocada, revocada o sin los permisos indicados en el paso 1 |
| "This Mercado Pago account is …; only Mercado Pago Brasil (BRL) is supported" | Usa las credenciales de una cuenta brasileña |
| "Mercado Pago: HTTP 401 …" | El Access token está equivocado o venció. Cópialo de nuevo |
| "Invalid Yappy secret key" o "Yappy: … (code)" | El Merchant ID, la Secret key o el dominio no coinciden con lo registrado en Yappy Comercial |
| "Something went wrong. Try again." | Una falla genérica, que también aparece cuando el proveedor rechaza cancelar una suscripción. Revisa el panel del proveedor e inténtalo de nuevo |
| El cliente no ve ningún botón de pagar | La factura es un borrador, está pagada o anulada, no tiene saldo, la forma de pago está sin marcar o inactiva, el proveedor está desactivado, o el proveedor no acepta la moneda de la factura |
| El cliente pagó pero la factura no cambió | Espera unos minutos: la red de seguridad revisa cada 5. Si no cambia, mira las entregas del webhook en el panel del proveedor. Una respuesta 400 significa que la firma no coincidió (revisa la Webhook secret signature en Mercado Pago, o la Secret key en Yappy); una respuesta 404 significa que la dirección no es la que dio el sistema (la Webhook URL de la tarjeta de Mercado Pago) |
| El cliente de Yappy ve "The payment was declined or the request expired…" | Pide al cliente que lo intente de nuevo, escribiendo el celular de 8 dígitos registrado en Yappy |
| "Provider is invalid" al crear una suscripción | El proveedor de esa forma de pago no acepta la moneda del plan: usa Stripe para USD, EUR o BRL, Mercado Pago para BRL, Yappy para USD |
| El cliente ve "We could not start the subscription…" | La suscripción ya no está abierta (ya activa o cancelada), el proveedor la rechazó, o en Mercado Pago el correo no es válido. Crea un enlace nuevo si hace falta |
| Un cobro de suscripción apareció en Mercado Pago y no aquí | Falta el webhook con los eventos Payments y Plans and subscriptions en el panel de Mercado Pago (paso 1) |
| Una suscripción está **Past due** | La última renovación fue rechazada o no se pagó. El cliente debe corregir la tarjeta o pagar la factura de renovación |

## No incluido
- Sin devoluciones ni contracargos registrados en el sistema; se resuelven en el panel del proveedor.
- Sin traspaso de la comisión al cliente: la empresa absorbe la comisión del proveedor.
- Solo las facturas se pagan en línea; una cotización no se puede pagar hasta que se convierta en factura.
- Una sola conexión por proveedor en cada cuenta, y solo Stripe, Mercado Pago y Yappy.
- Sin prueba gratis, cupones ni cambio de plan con cobro proporcional: para cambiar de plan, cancela y crea una suscripción nueva.
- Sin código QR de Pix en nuestra página: el Pix se ofrece dentro de la página de Mercado Pago.
- Sin lista de suscripciones en la tarjeta del contacto.
- Sin recordatorio automático de facturas sin pagar, salvo las renovaciones de Yappy.
