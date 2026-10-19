# Página pública do catálogo: a sua vitrine

Uma página web pública com os itens disponíveis do seu catálogo, com fotos e preços, que você pode compartilhar nas redes sociais, na bio ou no seu site. Cada item tem um botão que abre uma conversa de WhatsApp com a sua empresa sobre aquele item. Você a publica em **CRM → Catalog → Company & payments → Public catalog**.

*Também em: [English](comercial-vitrine.en.md) · [Español](comercial-vitrine.es.md)*

*Módulo Commerce: [Catálogo e empresa](comercial-catalogo.pt.md) · [Orçamentos e faturas](comercial-documentos.pt.md) · [Cobrança online e assinaturas](comercial-cobranca.pt.md)*

## Antes de começar

1. **Commerce ligado** na sua conta (um administrador da instalação faz isso no Super Admin, marcando **Commerce** nas funções da conta). Se for desligado, a página para de funcionar.
2. **Itens no catálogo**, com a caixa **Available** marcada, e fotos se quiser uma página bonita. Veja [Catálogo e empresa](comercial-catalogo.pt.md).
3. **O WhatsApp da empresa** preenchido em **Company details**, com o código do país (por exemplo +507 …). O botão de cada item abre esse número. Só contam os dígitos.
4. **Os dados da empresa** que você quer que os visitantes vejam: logo, nome comercial, telefone, e-mail, site e rodapé.
5. **Quem pode fazer o quê.** Só os administradores publicam a página (**Company & payments** é para administradores).

## Passo a passo

### 1. Publique a página
**CRM → Catalog → Company & payments → Public catalog**. Marque **Publish the catalog page**. Vale na hora, sem clicar em **Save**, e o link aparece. (Essa caixa também salva qualquer outra mudança que você tenha digitado em Company details.)

Se o WhatsApp estiver vazio, você vê "Fill in WhatsApp in the company data above: without it, the button opens an email to you instead." Sem WhatsApp e sem Email, os itens não mostram botão.

### 2. Compartilhe o link
O link tem a forma `…/c/` seguida de um código longo. Clique em **Copy link** ("Link copied") ou clique no link para ver a página. Acrescente `?lang=en`, `?lang=es` ou `?lang=pt` no fim para forçar o idioma da página; sem isso, a página usa o idioma da sua conta (espanhol quando não é nenhum dos três).

Para tirar a página do ar, desmarque **Publish the catalog page**. O endereço passa a responder "não encontrado" para todo mundo. O código do link é criado uma vez só e continua o mesmo se você publicar de novo; não há botão para gerar um novo.

### 3. O que o visitante vê
- O logo, o nome comercial, o telefone, o e-mail e o site da empresa.
- O título **Catalog**, no idioma da página.
- Quando os itens disponíveis pertencem a mais de uma categoria, uma fileira de filtros: "All" e um por categoria.
- Um cartão por item disponível: a primeira foto (ou uma caixa vazia), a categoria, o nome, o preço, a descrição (cortada em 220 caracteres) e o botão.
- O preço aparece como "price / unit" num item de pagamento único, "price per month" ou "price per year" num plano, e "Price on request" num item sem preço.
- O rodapé da empresa no fim.
- Se não houver nada disponível: "No products available right now."

### 4. O que o visitante faz
O visitante clica em **I want this** (em espanhol "Lo quiero", em português "Quero este"). O botão abre o WhatsApp com o seu número e uma mensagem pronta no idioma da página, como "Hi, I am interested in: Item name". Se não houver WhatsApp mas houver Email, abre um e-mail para a empresa com essa mensagem como assunto.

Não há carrinho, nem checkout, nem pagamento na página.

### 5. Onde chegam os pedidos
Nada é registrado na página. O "pedido" é a conversa que começa no WhatsApp:
1. A mensagem chega na sua caixa como qualquer outra mensagem de cliente, se esse número de WhatsApp estiver conectado como uma das suas caixas.
2. A sua equipe (ou o assistente de IA, se ele vende a partir do catálogo) responde. A IA pode preparar um orçamento em rascunho com os preços do catálogo ou enviar o link de um plano de assinatura. Veja [Orçamentos e faturas](comercial-documentos.pt.md) e [Cobrança online e assinaturas](comercial-cobranca.pt.md).
3. A sua equipe revisa e envia o orçamento, a fatura ou o link da assinatura.

### 6. Mantenha em dia
A página sempre mostra o catálogo atual. Desmarque **Available** num item para tirá-lo da página, mude o preço no item, adicione ou troque fotos (até 10 por item; a página usa a primeira). As mudanças aparecem na próxima vez que a página é aberta.

## Quando algo falha ou não aparece

| O que você vê | O que fazer |
|---|---|
| O link responde "não encontrado" | **Publish the catalog page** está desmarcado, o código do link está incompleto, ou **Commerce** está desligado na conta |
| A página diz "No products available right now." | Nenhum item tem **Available** marcado |
| Falta um item | Confira **Available** nesse item |
| O item está sem foto | Adicione imagens ao item no Catalog |
| O botão abre um e-mail em vez do WhatsApp | O campo **WhatsApp** de Company details está vazio |
| Não há botão | **WhatsApp** e **Email** estão os dois vazios |
| A conversa de WhatsApp abre com o número errado | Corrija o campo **WhatsApp**, com o código do país e só os dígitos reais |
| A página está no idioma errado | Acrescente `?lang=en`, `?lang=es` ou `?lang=pt` ao link |
| Não há filtros de categoria | Os filtros só aparecem quando os itens disponíveis pertencem a duas ou mais categorias |

## Não incluído
- Sem carrinho, checkout, pagamento online nem estoque na página: toda venda começa como uma conversa de WhatsApp.
- Sem lista nem registro de pedidos: use as conversas, orçamentos e faturas.
- Sem campo de busca, sem página por item e sem galeria (só a primeira foto de cada item).
- Sem domínio próprio, cores nem layout personalizados, e sem como gerar um link novo.
- Sem como esconder o preço de um item além de deixar o preço em branco, o que mostra "Price on request".
- Os planos aparecem com o preço por mês ou por ano, mas o botão é o mesmo botão de WhatsApp: a assinatura é combinada na conversa.
