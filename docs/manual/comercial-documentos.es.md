# Cotizaciones y facturas: crear, enviar y seguir

Crea cotizaciones, facturas y recibos con tu marca en español, portugués o inglés, envíalos por chat o correo, deja que el cliente acepte una cotización o pague una factura en un enlace, y guarda todos los PDF. Está en el menú, en **CRM → Quotes & invoices**.

*También en: [English](comercial-documentos.en.md) · [Português](comercial-documentos.pt.md)*

*Módulo Commerce: [Catálogo y empresa](comercial-catalogo.es.md) · [Cobros en línea y suscripciones](comercial-cobranca.es.md) · [Página pública del catálogo](comercial-vitrine.es.md)*

## Antes de empezar

1. **Commerce activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, marcando **Commerce** en las funciones de la cuenta).
2. **Datos de la empresa completos**: nombre, logo, identificación fiscal, condiciones por defecto y prefijos de numeración. Todo documento los copia. Mira [Catálogo y empresa](comercial-catalogo.es.md).
3. **Los ítems del catálogo** son opcionales: una línea también se puede escribir libremente.
4. **Para enviar por chat**, el cliente debe ser un contacto con una conversación en un canal que entregue mensajes al cliente (WhatsApp, por ejemplo). Una bandeja que solo guarda transcripciones de llamadas no entrega nada y no se ofrece. **Para enviar por correo**, necesitas el correo del cliente, y la instalación debe poder enviar correos.
5. **Para que el cliente pague en línea**, conecta antes un proveedor. Mira [Cobros en línea y suscripciones](comercial-cobranca.es.md).
6. **Quién puede hacer qué.** Todo el equipo crea, edita, genera PDF, envía, marca cotizaciones como aceptadas o rechazadas, crea facturas, reabre y archiva. Solo los administradores pueden usar **Void**, **Delete draft**, registrar o quitar pagos y emitir un recibo a mano.

## Paso a paso

### 1. Crea el documento
**CRM → Quotes & invoices**. Las pestañas **Quotes**, **Invoices** y **Receipts** cambian la lista. Pulsa **New quote** o **New invoice**. Se crea de inmediato un **Draft** (borrador), con su número (por ejemplo `COT-2026-0001`), la fecha de hoy, la moneda por defecto, las condiciones y el pie de página por defecto de la empresa, y todas las formas de pago activas marcadas.

Los recibos no se crean aquí: nacen de los pagos (mira el paso 11). Para hacer una factura a partir de una cotización, mira el paso 9.

### 2. Completa el cliente
En el bloque **Customer**, escribe al menos 2 letras en "Search a contact to fill in" y elige el contacto: se completan el nombre, el correo, el teléfono y los datos fiscales recordados de documentos anteriores. O escribe todo a mano: Name, Tax ID type, Tax ID, Email, Phone y Address.
- La identificación fiscal y la dirección que escribes quedan recordadas en el contacto para el próximo documento.
- Elige un contacto si quieres enviar por chat. Un documento sin contacto solo se puede enviar por correo.

### 3. Elige los ajustes del documento
En el bloque **Document**:

| Campo | Qué hace |
|---|---|
| Document language | Español, portugués o inglés. El PDF, la página del cliente, el correo y el texto del chat usan ese idioma |
| Currency | USD, BRL o EUR. Nada se convierte: los precios de las líneas son números en esta moneda |
| Prices and taxes | **Prices without tax (tax is added)**, **Prices include tax** o **Tax exempt**. Mira el ejemplo de abajo |
| Issue date | Empieza como hoy |
| Valid until (cotización) / Due date (factura) | Opcional. Pasada esta fecha, una cotización enviada muestra **Expired** y una factura sin pagar muestra **Overdue** |
| Payment methods shown on this document | Las formas activas de la empresa, todas marcadas. Las marcadas "(Pay button)" cobran en línea |

Ejemplo con una línea de 2 × 100.00, descuento 10% e impuesto 7%:
- **Prices without tax:** Subtotal 200.00, Discount 20.00, Tax 12.60, **Total 192.60**.
- **Prices include tax:** los 180.00 después del descuento ya contienen el impuesto. Total 180.00, "Tax included" 11.78.
- **Tax exempt:** la columna de impuesto desaparece y el total es 180.00.

### 4. Agrega los ítems
En el bloque **Items**, elige en **Add from catalog…** o pulsa **Add line** para una línea libre. Cada línea tiene el nombre y una descripción, **Qty**, **Unit**, **Unit price**, **Disc. %** y **Tax %** (no aparece cuando el documento está exento de impuestos), y el total de la línea. La cruz quita una línea.
- Una línea con el precio unitario vacío se muestra al cliente como "Price on request" y cuenta como cero en el total.
- Los totales de la pantalla (**Subtotal**, **Discount**, **Tax**, **Total**) son una vista previa mientras escribes. Después de **Save**, valen los números calculados por el servidor.

### 5. Notas, condiciones y pie de página
Al final: **Notes**, **Default terms** (así se llama el campo en el editor) y **Footer**. Se imprimen en el PDF y en la página del cliente. Las condiciones y el pie empiezan con los valores por defecto de la empresa y se pueden cambiar en cada documento.

### 6. Guarda, genera el PDF y conserva el archivo
- **Save** guarda tus cambios ("Saved.").
- **Generate PDF** guarda primero, crea un PDF nuevo y lo abre en otra pestaña.
- **PDF archive** lista todos los PDF generados del documento, con su fecha.
- **Send** siempre adjunta el PDF **más reciente**. Si cambiaste el documento después de generar un PDF, pulsa **Generate PDF** otra vez antes de enviar. (Si el documento todavía no tiene PDF, se hace uno al enviar.)
- El PDF admite letras de Europa occidental. Otros caracteres, como el cirílico o los emojis, se imprimen como "?".

### 7. Envíalo al cliente
Pulsa **Send**. La ventana "Send COT-2026-0001" tiene dos pestañas.
- **Chat:** elige la conversación (la lista muestra la bandeja, el número, el estado y el último mensaje) y, si quieres, escribe un **Message**. El cliente recibe **dos mensajes**: primero el PDF solo, y después un texto con el enlace del documento. Sin mensaje propio, el texto es el de por defecto en el idioma del documento, con el primer nombre del cliente, el total (el saldo en las facturas) y el enlace.
- **Email:** **To** (empieza con el correo del cliente), **Subject** y **Message**, ambos con un valor por defecto en el idioma del documento. El cliente recibe un correo con tu logo, el número, el total y el plazo, un botón a la página del documento ("Pay online" en facturas con pago en línea) y el PDF adjunto. Las respuestas van al correo de la empresa.

Al enviarse, un **Draft** pasa a **Sent** y el documento recuerda la conversación y el correo usados. Los recibos siguen los mismos canales. Puedes volver a enviar cuando quieras.

### 8. Qué ve el cliente
El botón **Customer link** (aparece cuando el documento ya no es un borrador) abre la página que recibe el cliente. Un borrador no tiene página. La página muestra la empresa, el documento, las líneas, los totales, las formas de pago sin cobro en línea con sus instrucciones, las notas, las condiciones y el pie, en el idioma del documento.

| Botón | English | Español | Português |
|---|---|---|---|
| Aceptar la cotización | Accept quote | Aceptar cotización | Aceitar orçamento |
| Rechazar la cotización | Decline | Rechazar | Recusar |
| Descargar el PDF | Download PDF | Descargar PDF | Baixar PDF |
| Pagar en línea (facturas) | Pay with … | Pagar con … | Pagar com … |

Los botones de aceptar y rechazar solo existen en una cotización **Sent** que no venció. El botón de pagar solo existe en una factura con saldo (mira [Cobros en línea y suscripciones](comercial-cobranca.es.md)).

### 9. Cuando el cliente responde
- **Accept quote / Decline** en el enlace pasan la cotización a **Accepted** o **Declined**, y el cliente ve una confirmación en la página.
- Si la cotización se envió **por una conversación**, aparece en ella una nota interna (privada) que menciona al responsable del negocio (o al primer administrador cuando no hay negocio), con el total y un enlace al documento. La mención le llega a esa persona como notificación en la campana. En una aceptación, la nota dice que hay que crear la factura. Una cotización enviada solo por correo no genera nota.
- Tu equipo puede responder en lugar del cliente con **Mark accepted** y **Mark declined**. Estos no crean nota ni factura automática.
- Una cotización pasada de su fecha **Valid until** ya no se puede responder en el enlace, pero **Mark accepted** sigue funcionando.

### 10. Crea la factura
- **Create invoice**, en una cotización que no esté Declined ni Void, crea una factura nueva en **Draft** con el mismo cliente, líneas, textos y formas de pago, y la abre. La cotización pasa a **Accepted** si todavía no lo estaba. La fecha de vencimiento no se copia: defínela en la factura. Pulsa el botón **una sola vez**: cada pulsación crea otra factura.
- **Factura automática.** En **Company & payments → Automation**, marca "When the customer accepts a quote on its link, create the invoice and send it through the same channels as the quote (chat and email)". Desde entonces, cuando un cliente pulsa **Accept quote**, la factura se crea y se envía por la misma conversación y por el último correo usado en la cotización, y la nota interna avisa a tu equipo que la factura fue creada. No actúa con **Mark accepted**, no se repite si la cotización ya tiene factura y viene desactivada.

### 11. Facturas, pagos y recibos
- Una factura pasa a **Partially paid** cuando los pagos recibidos son menores que el total, y a **Paid** cuando lo alcanzan. El bloque **Payments received** aparece cuando la factura ya no es un borrador.
- Los **pagos en línea** se registran solos, con la marca "Online" y el número del recibo. Mira [Cobros en línea y suscripciones](comercial-cobranca.es.md).
- **Record payment** (administradores) registra un pago recibido fuera del sistema. Campos: **Amount** (empieza con el saldo), **Paid on**, **Payment methods**, **Note**, y la casilla **Issue and send the receipt**, marcada por defecto.
- Cuando una factura queda **Paid**, el negocio abierto del contacto en el Pipeline pasa a Won, con el valor de la factura.
- El ícono de papelera quita un pago registrado a mano (administradores). La factura vuelve a Sent o a Partially paid y el recibo de ese pago pasa a **Void**. Los pagos en línea no se pueden quitar aquí: devuélvelos en el panel del propio proveedor, porque el sistema no registra devoluciones.
- **El recibo** es un documento propio (`REC-2026-0001`) con el monto recibido, la forma, la fecha, el total de la factura, lo pagado a la fecha y el saldo. Se envía por la conversación de la factura y por el último correo usado en la factura. Si la factura nunca se envió por chat ni por correo, el recibo se crea pero no se envía: ábrelo en la pestaña **Receipts** y pulsa **Send**. Junto a un pago que no tiene recibo, los administradores ven **Issue receipt**.
- Un recibo no puede cambiar el monto, la forma, el cliente ni las fechas. Puedes cambiar su idioma, notas, condiciones y pie, y generar su PDF otra vez.

### 12. Archivar, reabrir, anular y eliminar
- **Archive** saca el documento de la lista principal; el botón **Archived** muestra los archivados, y **Unarchive** lo devuelve.
- **Reopen for editing** devuelve a **Draft** un documento **Accepted**, **Declined** o **Void**. No está disponible cuando la factura ya tiene pagos. Los PDF generados se quedan en el archivo.
- **Void** (administradores) anula un documento que no tiene pagos.
- **Delete draft** (administradores) elimina un borrador para siempre; haz clic otra vez donde dice "Click again to delete". Los recibos no se pueden eliminar.
- Un documento **Sent** todavía se puede editar, y la página del cliente muestra el cambio de inmediato. El PDF ya enviado no cambia. Un documento **Accepted**, **Declined**, **Partially paid**, **Paid** o **Void** no se puede editar si no se reabre.

### 13. Borradores preparados por la IA
Si el asistente de IA de la cuenta vende desde el catálogo y un cliente pide una cotización, la IA crea una cotización en **Draft** con los precios del catálogo, vinculada a la conversación, y deja una nota interna que menciona al responsable del negocio (o al primer administrador).
- La cotización muestra la marca **Prepared by AI** en la lista y en el editor, y aparece un número rojo junto a **Quotes & invoices** en el menú, que cuenta esos borradores (se actualiza cada minuto).
- Ábrela: el aviso dice "The AI prepared this quote from conversation #… with the catalog prices. Review the items, quantities and customer, then send it." **Open the conversation** te lleva al chat.
- Revisa, cambia lo que necesites y pulsa **Send**. El número baja.
- Si el cliente cambia el pedido antes de que envíes, la IA actualiza el mismo borrador y deja una nota nueva.

## Estados y qué los mueve

| Documento | Estados |
|---|---|
| Cotización | **Draft**, **Sent**, **Accepted**, **Declined**, **Void**. **Expired** se muestra cuando una cotización enviada pasó de su fecha "Valid until" |
| Factura | **Draft**, **Sent**, **Partially paid**, **Paid**, **Void**. **Overdue** se muestra cuando una factura enviada o parcialmente pagada pasó de su fecha de vencimiento; todavía se puede pagar |
| Recibo | **Draft** (creado, aún no enviado), **Sent**, **Void** |

| Acción | Desde | Hasta | Quién |
|---|---|---|---|
| Send | Draft | Sent | Equipo |
| Accept quote / Decline (enlace del cliente) | Cotización Sent | Accepted / Declined | Cliente |
| Mark accepted / Mark declined | Cotización Draft o Sent | Accepted / Declined | Equipo |
| Create invoice | Cotización Draft, Sent o Accepted | Cotización Accepted, factura nueva en Draft | Equipo |
| Pago recibido | Factura Sent o Partially paid | Partially paid / Paid | Cliente en línea, o administradores a mano |
| Remove payment | Factura Partially paid o Paid | Sent / Partially paid | Administradores |
| Reopen for editing | Accepted, Declined o Void | Draft | Equipo |
| Void | Cualquier documento sin pagos, salvo recibos | Void | Administradores |

## Cuando algo falla o no aparece

| Qué ves | Qué hacer |
|---|---|
| "COT-2026-0001 is accepted and can no longer be edited" | El documento está cerrado. Usa primero **Reopen for editing** |
| "COT-2026-0001 is declined: action not allowed" (u otro estado) | La acción no se aplica a ese estado, por ejemplo anular un documento que tiene pagos, reabrir una factura pagada o crear una factura desde una cotización rechazada |
| "Inbox name does not deliver messages to the customer" | Esa conversación no llega al cliente. Elige otra conversación o envía por correo |
| "This customer has no conversation yet. Pick a contact on the document or send by email." | El documento no tiene contacto, o el contacto no tiene una conversación que entregue. Elige el contacto en el bloque **Customer** o usa la pestaña **Email** |
| El correo dice "Sent." pero el cliente no lo recibe | El sistema no muestra los errores de entrega de correo. Pide al cliente que revise la carpeta de spam y pide al administrador de la instalación que revise la configuración del correo |
| El cliente ve valores antiguos en el PDF | **Send** usa el último PDF. Pulsa **Generate PDF** después de editar y envía otra vez |
| El cliente abre el enlace y no encuentra nada | El documento sigue en **Draft**. Envíalo primero |
| El cliente no puede aceptar ni rechazar | La cotización no está **Sent**, o pasó su fecha "Valid until" |
| **Delete draft**, **Void** o **Record payment** fallan o no aparecen | Son solo para administradores |
| No apareció nota interna después de que el cliente aceptó | La cotización no se envió por una conversación. El estado cambia de todos modos |
| La factura creada por la opción automática quedó en Draft | La cotización no tenía conversación ni correo por donde enviar. Abre la factura y envíala |

## No incluido
- Sin facturas fiscales (NF-e, factura electrónica de la DGI): los documentos son comerciales.
- Sin firma electrónica de la cotización, más allá de que el cliente pulse **Accept quote**.
- Sin notas de crédito, devoluciones ni recordatorios automáticos de facturas sin pagar (los únicos recordatorios son los de las suscripciones de Yappy).
- Los números no se pueden editar ni reiniciar a mano.
- Sin plantillas listas, aparte del único diseño de PDF, que usa tu logo, los datos de la empresa, las notas, las condiciones y el pie.
- Los recibos no se pueden crear desde cero: siempre nacen de un pago de una factura.
- Una cotización no se puede pagar en línea: crea primero la factura.
