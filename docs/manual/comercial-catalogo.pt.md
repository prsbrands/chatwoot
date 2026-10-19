# Catálogo e empresa: produtos, preços e formas de pagamento

Aqui você define o que vende e os dados impressos em cada orçamento, fatura e recibo: seus produtos e serviços, os dados da sua empresa e as formas de pagamento que aceita. O catálogo fica no menu, em **CRM → Catalog**. Os dados da empresa e as formas de pagamento ficam em **Company & payments**, que se abre com o botão de mesmo nome no alto da página do Catalog.

*Também em: [English](comercial-catalogo.en.md) · [Español](comercial-catalogo.es.md)*

*Módulo Commerce: [Orçamentos e faturas](comercial-documentos.pt.md) · [Cobrança online e assinaturas](comercial-cobranca.pt.md) · [Página pública do catálogo](comercial-vitrine.pt.md)*

## Antes de começar

1. **Commerce ligado** na sua conta (um administrador da instalação faz isso no Super Admin, marcando **Commerce** nas funções da conta). Com ele ligado, **Quotes & invoices**, **Subscriptions** e **Catalog** aparecem no menu, em CRM.
2. **Quem pode fazer o quê.** Os administradores criam e alteram tudo. Os agentes podem abrir o Catalog para consultar e usar os itens em orçamentos e faturas, mas não podem editar itens nem abrir **Company & payments**.
3. **Uma moeda.** O módulo trabalha em **USD**, **BRL** e **EUR**, e só nelas. Escolha a que você mais usa como moeda padrão. Cada item e cada documento continua levando a sua própria moeda.
4. **Um arquivo de logo** (PNG, JPEG ou WebP), se quiser o seu logo nos documentos.
5. As cobranças online (Stripe, Mercado Pago, Yappy) são conectadas na mesma página de **Company & payments**, mas têm manual próprio: [Cobrança online e assinaturas](comercial-cobranca.pt.md).

## Passo a passo

### 1. Preencha os dados da empresa
**CRM → Catalog → Company & payments** (só administradores; também está em **View all in CRM**, em "Setting up the sale"). No bloco **Company details**:

| Campo | O que escrever |
|---|---|
| Logo | **Upload logo** (PNG, JPEG ou WebP) ou **Remove logo**. Impresso no PDF, na página do cliente e no e-mail |
| Trade name | O nome pelo qual os clientes conhecem você. Impresso como nome principal |
| Legal name | Impresso abaixo do nome comercial quando for diferente |
| Tax ID type / Tax ID | Por exemplo "RUC, CNPJ, EIN…" e o número |
| Phone, WhatsApp, Email, Website | Impressos nos documentos. O WhatsApp também alimenta o botão da [página pública do catálogo](comercial-vitrine.pt.md) |
| Address | Impresso abaixo do nome da empresa |
| Default currency | USD, BRL ou EUR. A moeda de todo documento novo |
| Default terms | Texto copiado para cada orçamento e fatura nova: validade, prazo de entrega, condições de pagamento… |
| Footer | Uma linha no rodapé de cada documento, por exemplo "Thank you for your business." |
| Quote prefix / Invoice prefix / Receipt prefix | O começo dos números dos documentos (COT, FAT e REC por padrão). Veja "Números dos documentos" abaixo |

Clique em **Save**. Você vê "Company details saved."

- Cada documento guarda **a sua própria cópia** dos dados da empresa. A cópia é renovada toda vez que você salva um documento que ainda está em **Draft** ou **Sent**. Documentos aceitos, pagos ou anulados, e PDFs já gerados, não mudam.
- **Default terms** e **Footer** são copiados para o documento quando ele é criado. Alterá-los depois só afeta os documentos novos.

### 2. Números dos documentos
Cada documento recebe o seu número no momento em que é criado: prefixo, ano e uma sequência de 4 dígitos, por exemplo `COT-2026-0001`, `FAT-2026-0001`, `REC-2026-0001`.
- A sequência é separada para orçamentos, faturas e recibos, e volta a 0001 a cada ano (o ano é a data de emissão do documento).
- Um prefixo tem de 1 a 8 letras ou dígitos e é salvo em maiúsculas. Alterá-lo só afeta os documentos novos.
- Um número não pode ser editado à mão, e não há ajuste para escolher o próximo número da sequência.

### 3. Impostos, moeda e idioma
- **Os impostos não são definidos aqui.** Não existe uma alíquota de imposto da empresa. Cada documento tem uma opção "Prices and taxes" e cada linha tem um "Tax %" (veja [Orçamentos e faturas](comercial-documentos.pt.md)).
- **A moeda** tem um padrão aqui, mas cada documento e cada item tem a sua. Nada é convertido de uma moeda para outra.
- **O idioma** é escolhido por documento (espanhol, português ou inglês), e não por empresa, porque uma mesma conta pode atender clientes de vários países. Os documentos novos começam no idioma da sua conta quando é um dos três, e senão em espanhol.
- Este módulo não tem ajuste de fuso horário: as datas são datas de calendário simples.

### 4. Formas de pagamento
**Company & payments → Payment methods → New payment method**.

| Campo | O que faz |
|---|---|
| Name | O que o cliente lê, por exemplo "Bank transfer — Banco General". É também o texto do botão **Pay with** quando a forma cobra online |
| Type | Cash, Bank transfer, Pix, Yappy, Card, Payment link ou Other. Uma etiqueta para manter a ordem; não muda o funcionamento da forma de pagamento |
| Online charge | Aparece quando há um provedor online conectado. "None (instructions only)" ou o provedor que cobra o cliente. Veja [Cobrança online e assinaturas](comercial-cobranca.pt.md) |
| Instructions for the customer | Número da conta, chave Pix, número do Yappy… Impresso no PDF e na página do cliente |
| Active | Só as formas ativas podem aparecer nos documentos |

Clique em **Save**. Clique numa forma de pagamento da lista para editá-la. Uma forma inativa mostra a marca "Inactive". A lista mostra "Online with Stripe" (ou o provedor) nas formas que cobram online.

Como as formas de pagamento chegam ao cliente:
- Um documento novo começa com **todas as formas ativas marcadas** em "Payment methods shown on this document". Desmarque as que você não quer nesse documento.
- A página do cliente lista as formas **sem** cobrança online, com as suas instruções. As formas **com** cobrança online viram botões "Pay with …" nas faturas que têm saldo.
- O PDF lista o nome e as instruções de cada forma escolhida, exceto quando o documento está pago ou anulado.

Para excluir uma forma de pagamento, use o ícone de lixeira (ou **Delete payment method** dentro da forma) e confirme "Delete {name}?". A forma some de todos os documentos que a mostravam. Uma forma que já tem pagamentos ou cobranças online **não pode ser excluída**: desmarque **Active** e ela fica oculta.

### 5. Categorias
Na página do Catalog clique em **Categories**.
- Digite um nome em "New category" e clique em **Add**.
- Para renomear, edite o nome e clique fora do campo.
- O ícone de lixeira exclui uma categoria. Os itens dela ficam sem categoria.
- Um nome tem até 80 caracteres.

### 6. Crie um item
**Catalog → New item**.

| Campo | O que faz |
|---|---|
| Type | Product ou Service |
| Category | Uma das suas categorias, ou "No category" |
| Name | Obrigatório, até 160 caracteres |
| Code (SKU) | O seu próprio código, até 60 caracteres |
| Description | Texto livre. Copiado para a linha do documento e mostrado no catálogo público |
| Price | Deixe em branco quando é orçado, medido ou feito sob encomenda: o item aparece então como "Price on request" |
| Currency | USD, BRL ou EUR |
| Unit | unit, hour, day, week, month, m, m², m³, kg, liter, package, project ou service |
| Billing | One-time, Monthly plan ou Yearly plan. Um plano é o que os clientes contratam numa assinatura e **precisa de preço**. Veja [Cobrança online e assinaturas](comercial-cobranca.pt.md) |
| Available | Desmarcado, o item mostra a marca "Unavailable" e sai da lista "Add from catalog…" dos documentos, da lista de planos das assinaturas, do catálogo público e do assistente de IA |

Clique em **Save**. Num item novo a janela continua aberta com "Item created. You can add images now."
- **Imagens:** **Add images** aceita PNG, JPEG ou WebP, até 10 por item ("Images (2 of 10)"). Passe o mouse sobre uma imagem e clique no ícone de lixeira para tirá-la. A primeira imagem é a capa.
- **Editar:** clique no cartão do item (administradores).
- **Excluir:** **Delete item** e depois clique de novo onde diz "Click again to delete". Orçamentos, faturas e assinaturas já feitos guardam a sua própria cópia.

O preço no cartão aparece como "price / unit" nos itens de pagamento único, "price / month" ou "price / year" nos planos, e "Price on request" quando não há preço.

### 7. Procure itens
Na página do Catalog: o campo de busca ("Search by name, code or description") ignora acentos e maiúsculas, e há dois filtros, um por tipo ("Products and services", Product, Service) e outro por categoria ("All categories").

### 8. Use os itens num orçamento ou fatura
No editor de um documento, a lista **Add from catalog…** mostra os itens disponíveis com o preço. Ao escolher um, entra uma linha com o nome, a descrição, a unidade e o preço copiados do item. Você pode mudar a linha à vontade; o catálogo não muda.
- O preço é copiado como número. **Não há conversão de moeda**: use itens na mesma moeda do documento, ou corrija o preço unitário na linha.
- As linhas livres (**Add line**) não precisam do catálogo.

## Quando algo falha ou não aparece

| O que você vê | O que fazer |
|---|---|
| "Something went wrong. Try again." | Uma falha genérica. Tente de novo; se se repetir, avise o administrador da instalação |
| "Quote prefix is invalid" (ou Invoice prefix, Receipt prefix) | Use de 1 a 8 letras ou dígitos, sem espaços nem símbolos |
| "Price can't be blank" ao salvar um item | Planos mensais e anuais precisam de preço |
| "This payment method already has payments or online charges, so it stays in the history. Uncheck Active to hide it." | A forma de pagamento não pode ser excluída. Desmarque **Active** |
| Clicar num item não faz nada | Só os administradores editam itens |
| O item não está em "Add from catalog…" | Ele não está com **Available** marcado |
| A forma de pagamento não tem o campo **Online charge** | Ainda não há um provedor online conectado. Veja [Cobrança online e assinaturas](comercial-cobranca.pt.md) |
| O logo não sai nos documentos | Use PNG, JPEG ou WebP. Os documentos que já foram salvos com o logo anterior são atualizados na próxima vez que forem salvos, se ainda estiverem em Draft ou Sent |

## Não incluído
- Sem importação nem exportação do catálogo por planilha: os itens são criados um a um.
- Sem variações (tamanho, cor), sem controle de estoque e sem imposto por item.
- Um preço e uma moeda por item, sem listas de preço e sem conversão automática.
- Os itens aparecem em ordem alfabética; não há ordem manual.
- Um só conjunto de dados de empresa por conta: sem filiais nem várias empresas na mesma conta.
- Os documentos são comerciais, não notas fiscais. Notas fiscais eletrônicas (como a NF-e ou a fatura eletrônica da DGI) não são emitidas aqui.
