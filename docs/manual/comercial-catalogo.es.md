# Catálogo y empresa: productos, precios y formas de pago

Aquí defines lo que vendes y los datos que se imprimen en cada cotización, factura y recibo: tus productos y servicios, los datos de tu empresa y las formas de pago que aceptas. El catálogo está en el menú, en **CRM → Catalog**. Los datos de la empresa y las formas de pago están en **Company & payments**, que se abre con el botón de ese nombre en la parte de arriba de la página del Catalog.

*También en: [English](comercial-catalogo.en.md) · [Português](comercial-catalogo.pt.md)*

*Módulo Commerce: [Cotizaciones y facturas](comercial-documentos.es.md) · [Cobros en línea y suscripciones](comercial-cobranca.es.md) · [Página pública del catálogo](comercial-vitrine.es.md)*

## Antes de empezar

1. **Commerce activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, marcando **Commerce** en las funciones de la cuenta). Con él activado, **Quotes & invoices**, **Subscriptions** y **Catalog** aparecen en el menú, en CRM.
2. **Quién puede hacer qué.** Los administradores crean y cambian todo. Los agentes pueden abrir el Catalog para consultar y usar los ítems en cotizaciones y facturas, pero no pueden editar ítems ni abrir **Company & payments**.
3. **Una moneda.** El módulo trabaja en **USD**, **BRL** y **EUR**, y solo en esas. Elige la que más usas como moneda por defecto. Cada ítem y cada documento sigue llevando su propia moneda.
4. **Un archivo de logo** (PNG, JPEG o WebP), si quieres tu logo en los documentos.
5. Los cobros en línea (Stripe, Mercado Pago, Yappy) se conectan en la misma página de **Company & payments**, pero tienen su propio manual: [Cobros en línea y suscripciones](comercial-cobranca.es.md).

## Paso a paso

### 1. Completa los datos de la empresa
**CRM → Catalog → Company & payments** (solo administradores; también está en **View all in CRM**, en "Setting up the sale"). En el bloque **Company details**:

| Campo | Qué escribir |
|---|---|
| Logo | **Upload logo** (PNG, JPEG o WebP) o **Remove logo**. Se imprime en el PDF, en la página del cliente y en el correo |
| Trade name | El nombre con el que te conocen tus clientes. Se imprime como nombre principal |
| Legal name | Se imprime debajo del nombre comercial cuando es distinto |
| Tax ID type / Tax ID | Por ejemplo "RUC, CNPJ, EIN…" y el número |
| Phone, WhatsApp, Email, Website | Se imprimen en los documentos. El WhatsApp también alimenta el botón de la [página pública del catálogo](comercial-vitrine.es.md) |
| Address | Se imprime debajo del nombre de la empresa |
| Default currency | USD, BRL o EUR. La moneda de todo documento nuevo |
| Default terms | Texto que se copia en cada cotización y factura nueva: validez, plazo de entrega, condiciones de pago… |
| Footer | Una línea al pie de cada documento, por ejemplo "Thank you for your business." |
| Quote prefix / Invoice prefix / Receipt prefix | El comienzo de los números de documento (COT, FAT y REC por defecto). Mira "Números de documento" más abajo |

Pulsa **Save**. Verás "Company details saved."

- Cada documento guarda **su propia copia** de los datos de la empresa. La copia se renueva cada vez que guardas un documento que sigue en **Draft** o **Sent**. Los documentos aceptados, pagados o anulados, y los PDF ya generados, no cambian.
- **Default terms** y **Footer** se copian al documento cuando se crea. Cambiarlos después solo afecta a los documentos nuevos.

### 2. Números de documento
Cada documento recibe su número en el momento en que se crea: prefijo, año y una secuencia de 4 dígitos, por ejemplo `COT-2026-0001`, `FAT-2026-0001`, `REC-2026-0001`.
- La secuencia es independiente para cotizaciones, facturas y recibos, y vuelve a 0001 cada año (el año es la fecha de emisión del documento).
- Un prefijo tiene de 1 a 8 letras o dígitos y se guarda en mayúsculas. Cambiarlo solo afecta a los documentos nuevos.
- Un número no se puede editar a mano, y no hay ajuste para elegir el siguiente número de la secuencia.

### 3. Impuestos, moneda e idioma
- **Los impuestos no se definen aquí.** No hay una tasa de impuesto de la empresa. Cada documento tiene una opción "Prices and taxes" y cada línea tiene un "Tax %" (mira [Cotizaciones y facturas](comercial-documentos.es.md)).
- **La moneda** tiene un valor por defecto aquí, pero cada documento y cada ítem tiene la suya. Nada se convierte de una moneda a otra.
- **El idioma** se elige por documento (español, portugués o inglés), no por empresa, porque una misma cuenta puede atender clientes de varios países. Los documentos nuevos empiezan en el idioma de tu cuenta cuando es uno de los tres, y si no, en español.
- Este módulo no tiene ajuste de zona horaria: las fechas son fechas de calendario simples.

### 4. Formas de pago
**Company & payments → Payment methods → New payment method**.

| Campo | Qué hace |
|---|---|
| Name | Lo que lee el cliente, por ejemplo "Bank transfer — Banco General". También es el texto del botón **Pay with** cuando la forma cobra en línea |
| Type | Cash, Bank transfer, Pix, Yappy, Card, Payment link u Other. Una etiqueta para mantener el orden; no cambia cómo funciona la forma de pago |
| Online charge | Aparece cuando hay un proveedor en línea conectado. "None (instructions only)" o el proveedor que cobra al cliente. Mira [Cobros en línea y suscripciones](comercial-cobranca.es.md) |
| Instructions for the customer | Número de cuenta, llave Pix, número de Yappy… Se imprime en el PDF y en la página del cliente |
| Active | Solo las formas activas pueden mostrarse en los documentos |

Pulsa **Save**. Haz clic en una forma de pago de la lista para editarla. Una forma inactiva muestra la marca "Inactive". La lista muestra "Online with Stripe" (o el proveedor) en las formas que cobran en línea.

Cómo llegan las formas de pago al cliente:
- Un documento nuevo empieza con **todas las formas activas marcadas** en "Payment methods shown on this document". Desmarca las que no quieras en ese documento.
- La página del cliente lista las formas **sin** cobro en línea, con sus instrucciones. Las formas **con** cobro en línea se convierten en botones "Pay with …" en las facturas que tienen saldo.
- El PDF lista el nombre y las instrucciones de cada forma elegida, salvo cuando el documento está pagado o anulado.

Para eliminar una forma de pago, usa el ícono de papelera (o **Delete payment method** dentro de la forma) y confirma "Delete {name}?". La forma desaparece de todos los documentos que la mostraban. Una forma que ya tiene pagos o cobros en línea **no se puede eliminar**: desmarca **Active** y queda oculta.

### 5. Categorías
En la página del Catalog pulsa **Categories**.
- Escribe un nombre en "New category" y pulsa **Add**.
- Para renombrar, edita el nombre y haz clic fuera del campo.
- El ícono de papelera elimina una categoría. Sus ítems quedan sin categoría.
- Un nombre tiene hasta 80 caracteres.

### 6. Crea un ítem
**Catalog → New item**.

| Campo | Qué hace |
|---|---|
| Type | Product o Service |
| Category | Una de tus categorías, o "No category" |
| Name | Obligatorio, hasta 160 caracteres |
| Code (SKU) | Tu propio código, hasta 60 caracteres |
| Description | Texto libre. Se copia a la línea del documento y se muestra en el catálogo público |
| Price | Déjalo en blanco cuando se cotiza, se mide o se hace a pedido: el ítem se muestra entonces como "Price on request" |
| Currency | USD, BRL o EUR |
| Unit | unit, hour, day, week, month, m, m², m³, kg, liter, package, project o service |
| Billing | One-time, Monthly plan o Yearly plan. Un plan es lo que los clientes contratan en una suscripción y **necesita precio**. Mira [Cobros en línea y suscripciones](comercial-cobranca.es.md) |
| Available | Sin marcar, el ítem muestra la marca "Unavailable" y sale de la lista "Add from catalog…" de los documentos, de la lista de planes de las suscripciones, del catálogo público y del asistente de IA |

Pulsa **Save**. En un ítem nuevo la ventana sigue abierta con "Item created. You can add images now."
- **Imágenes:** **Add images** acepta PNG, JPEG o WebP, hasta 10 por ítem ("Images (2 of 10)"). Pasa el cursor sobre una imagen y haz clic en el ícono de papelera para quitarla. La primera imagen es la portada.
- **Editar:** haz clic en la tarjeta del ítem (administradores).
- **Eliminar:** **Delete item** y luego haz clic otra vez donde dice "Click again to delete". Las cotizaciones, facturas y suscripciones ya hechas conservan su propia copia.

El precio en la tarjeta se lee "price / unit" en los ítems de pago único, "price / month" o "price / year" en los planes, y "Price on request" cuando no hay precio.

### 7. Busca ítems
En la página del Catalog: el campo de búsqueda ("Search by name, code or description") ignora tildes y mayúsculas, y hay dos filtros, uno por tipo ("Products and services", Product, Service) y otro por categoría ("All categories").

### 8. Usa los ítems en una cotización o factura
En el editor de un documento, la lista **Add from catalog…** muestra los ítems disponibles con su precio. Al elegir uno se agrega una línea con el nombre, la descripción, la unidad y el precio copiados del ítem. Puedes cambiar la línea libremente; el catálogo no cambia.
- El precio se copia como número. **No hay conversión de moneda**: usa ítems en la misma moneda del documento, o corrige el precio unitario en la línea.
- Las líneas libres (**Add line**) no necesitan el catálogo.

## Cuando algo falla o no aparece

| Qué ves | Qué hacer |
|---|---|
| "Something went wrong. Try again." | Una falla genérica. Inténtalo de nuevo; si se repite, avisa al administrador de la instalación |
| "Quote prefix is invalid" (o Invoice prefix, Receipt prefix) | Usa de 1 a 8 letras o dígitos, sin espacios ni símbolos |
| "Price can't be blank" al guardar un ítem | Los planes mensuales y anuales necesitan precio |
| "This payment method already has payments or online charges, so it stays in the history. Uncheck Active to hide it." | La forma de pago no se puede eliminar. Desmarca **Active** |
| Al hacer clic en un ítem no pasa nada | Solo los administradores editan ítems |
| El ítem no está en "Add from catalog…" | No tiene marcado **Available** |
| La forma de pago no tiene el campo **Online charge** | Todavía no hay un proveedor en línea conectado. Mira [Cobros en línea y suscripciones](comercial-cobranca.es.md) |
| El logo no sale en los documentos | Usa PNG, JPEG o WebP. Los documentos que ya se guardaron con el logo anterior se actualizan la próxima vez que se guarden, si siguen en Draft o Sent |

## No incluido
- Sin importación ni exportación del catálogo por planilla: los ítems se crean uno por uno.
- Sin variaciones (talla, color), sin control de inventario y sin impuesto por ítem.
- Un precio y una moneda por ítem, sin listas de precios y sin conversión automática.
- Los ítems aparecen en orden alfabético; no hay orden manual.
- Un solo conjunto de datos de empresa por cuenta: sin sucursales ni varias empresas en la misma cuenta.
- Los documentos son comerciales, no facturas fiscales. Aquí no se emiten facturas fiscales electrónicas (como la NF-e o la factura electrónica de la DGI).
