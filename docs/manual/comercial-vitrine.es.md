# Página pública del catálogo: tu vitrina

Una página web pública con los ítems disponibles de tu catálogo, con fotos y precios, que puedes compartir en redes sociales, en tu bio o en tu sitio. Cada ítem tiene un botón que abre un chat de WhatsApp con tu empresa sobre ese ítem. La publicas en **CRM → Catalog → Company & payments → Public catalog**.

*También en: [English](comercial-vitrine.en.md) · [Português](comercial-vitrine.pt.md)*

*Módulo Commerce: [Catálogo y empresa](comercial-catalogo.es.md) · [Cotizaciones y facturas](comercial-documentos.es.md) · [Cobros en línea y suscripciones](comercial-cobranca.es.md)*

## Antes de empezar

1. **Commerce activado** en tu cuenta (lo hace un administrador de la instalación en el Super Admin, marcando **Commerce** en las funciones de la cuenta). Si se desactiva, la página deja de funcionar.
2. **Ítems en el catálogo**, con la casilla **Available** marcada, y fotos si quieres una página bonita. Mira [Catálogo y empresa](comercial-catalogo.es.md).
3. **El WhatsApp de la empresa** completado en **Company details**, con el código de país (por ejemplo +507 …). El botón de cada ítem abre ese número. Solo cuentan los dígitos.
4. **Los datos de la empresa** que quieres que vean los visitantes: logo, nombre comercial, teléfono, correo, sitio web y pie de página.
5. **Quién puede hacer qué.** Solo los administradores publican la página (**Company & payments** es para administradores).

## Paso a paso

### 1. Publica la página
**CRM → Catalog → Company & payments → Public catalog**. Marca **Publish the catalog page**. Surte efecto de inmediato, sin pulsar **Save**, y aparece el enlace. (Esta casilla también guarda cualquier otro cambio que hayas escrito en Company details.)

Si el WhatsApp está vacío, verás "Fill in WhatsApp in the company data above: without it, the button opens an email to you instead." Sin WhatsApp y sin Email, los ítems no muestran botón.

### 2. Comparte el enlace
El enlace tiene la forma `…/c/` seguida de un código largo. Pulsa **Copy link** ("Link copied") o haz clic en el enlace para ver la página. Agrega `?lang=en`, `?lang=es` o `?lang=pt` al final para forzar el idioma de la página; sin eso, la página usa el idioma de tu cuenta (español cuando no es ninguno de los tres).

Para sacar la página del aire, desmarca **Publish the catalog page**. La dirección pasa a responder "no encontrado" para todos. El código del enlace se crea una sola vez y se mantiene igual si vuelves a publicar; no hay botón para generar uno nuevo.

### 3. Qué ve el visitante
- El logo, el nombre comercial, el teléfono, el correo y el sitio web de la empresa.
- El título **Catalog**, en el idioma de la página.
- Cuando los ítems disponibles pertenecen a más de una categoría, una fila de filtros: "All" y uno por categoría.
- Una tarjeta por ítem disponible: la primera foto (o un cuadro vacío), la categoría, el nombre, el precio, la descripción (cortada en 220 caracteres) y el botón.
- El precio se lee "price / unit" en un ítem de pago único, "price per month" o "price per year" en un plan, y "Price on request" en un ítem sin precio.
- El pie de página de la empresa al final.
- Si no hay nada disponible: "No products available right now."

### 4. Qué hace el visitante
El visitante pulsa **I want this** (en español "Lo quiero", en portugués "Quero este"). El botón abre WhatsApp con tu número y un mensaje listo en el idioma de la página, como "Hi, I am interested in: Item name". Si no hay WhatsApp pero sí Email, abre un correo a la empresa con ese mensaje como asunto.

No hay carrito, ni checkout, ni pago en la página.

### 5. Dónde llegan los pedidos
Nada se registra en la página. El "pedido" es la conversación que empieza en WhatsApp:
1. El mensaje llega a tu bandeja como cualquier otro mensaje de cliente, si ese número de WhatsApp está conectado como una de tus bandejas.
2. Tu equipo (o el asistente de IA, si vende desde el catálogo) responde. La IA puede preparar una cotización en borrador con los precios del catálogo o enviar el enlace de un plan de suscripción. Mira [Cotizaciones y facturas](comercial-documentos.es.md) y [Cobros en línea y suscripciones](comercial-cobranca.es.md).
3. Tu equipo revisa y envía la cotización, la factura o el enlace de la suscripción.

### 6. Mantenla al día
La página siempre muestra el catálogo actual. Desmarca **Available** en un ítem para sacarlo de la página, cambia el precio en el ítem, agrega o reemplaza fotos (hasta 10 por ítem; la página usa la primera). Los cambios se ven la próxima vez que se abre la página.

## Cuando algo falla o no aparece

| Qué ves | Qué hacer |
|---|---|
| El enlace responde "no encontrado" | **Publish the catalog page** está sin marcar, el código del enlace está incompleto, o **Commerce** está desactivado en la cuenta |
| La página dice "No products available right now." | Ningún ítem tiene **Available** marcado |
| Falta un ítem | Revisa **Available** en ese ítem |
| El ítem no tiene foto | Agrega imágenes al ítem en el Catalog |
| El botón abre un correo en vez de WhatsApp | El campo **WhatsApp** de Company details está vacío |
| No hay botón | **WhatsApp** y **Email** están los dos vacíos |
| El chat de WhatsApp se abre con el número equivocado | Corrige el campo **WhatsApp**, con el código de país y solo los dígitos reales |
| La página está en el idioma equivocado | Agrega `?lang=en`, `?lang=es` o `?lang=pt` al enlace |
| No hay filtros de categoría | Los filtros solo aparecen cuando los ítems disponibles pertenecen a dos o más categorías |

## No incluido
- Sin carrito, checkout, pago en línea ni inventario en la página: toda venta empieza como una conversación de WhatsApp.
- Sin lista ni registro de pedidos: usa las conversaciones, cotizaciones y facturas.
- Sin campo de búsqueda, sin página por ítem y sin galería (solo la primera foto de cada ítem).
- Sin dominio propio, colores ni diseño personalizados, y sin forma de generar un enlace nuevo.
- Sin forma de ocultar el precio de un ítem salvo dejar su precio en blanco, lo que muestra "Price on request".
- Los planes aparecen con su precio por mes o por año, pero el botón es el mismo botón de WhatsApp: la suscripción se arregla en la conversación.
