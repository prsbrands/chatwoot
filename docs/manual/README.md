# Manual de uso do CortexGen Chat

Um manual por recurso, nos três idiomas (`en`, `es`, `pt`), escrito para quem usa a tela, não para quem programa. **Todo recurso novo entra com o manual dos três idiomas na mesma entrega.**

| Recurso | English | Español | Português |
|---|---|---|---|
| Outreach (campanhas por QR) | [outreach.en.md](outreach.en.md) | [outreach.es.md](outreach.es.md) | [outreach.pt.md](outreach.pt.md) |
| Casos | [casos.en.md](casos.en.md) | [casos.es.md](casos.es.md) | [casos.pt.md](casos.pt.md) |
| Evolução da IA | [evolucao-ia.en.md](evolucao-ia.en.md) | [evolucao-ia.es.md](evolucao-ia.es.md) | [evolucao-ia.pt.md](evolucao-ia.pt.md) |
| Memória da IA | [memoria-ia.en.md](memoria-ia.en.md) | [memoria-ia.es.md](memoria-ia.es.md) | [memoria-ia.pt.md](memoria-ia.pt.md) |
| Comercial: empresa, pagamentos e catálogo | [comercial-catalogo.en.md](comercial-catalogo.en.md) | [comercial-catalogo.es.md](comercial-catalogo.es.md) | [comercial-catalogo.pt.md](comercial-catalogo.pt.md) |
| Comercial: cotizações, faturas e recibos | [comercial-documentos.en.md](comercial-documentos.en.md) | [comercial-documentos.es.md](comercial-documentos.es.md) | [comercial-documentos.pt.md](comercial-documentos.pt.md) |
| Comercial: cobrança online e assinaturas | [comercial-cobranca.en.md](comercial-cobranca.en.md) | [comercial-cobranca.es.md](comercial-cobranca.es.md) | [comercial-cobranca.pt.md](comercial-cobranca.pt.md) |
| Comercial: vitrine | [comercial-vitrine.en.md](comercial-vitrine.en.md) | [comercial-vitrine.es.md](comercial-vitrine.es.md) | [comercial-vitrine.pt.md](comercial-vitrine.pt.md) |
| Agenda (tipos, jornada, Google Calendar, a IA marca) | [agenda.en.md](agenda.en.md) | [agenda.es.md](agenda.es.md) | [agenda.pt.md](agenda.pt.md) |
| Funil de vendas, Radar de risco e Tarefas | [funil.en.md](funil.en.md) | [funil.es.md](funil.es.md) | [funil.pt.md](funil.pt.md) |
| Connections (WhatsApp por QR) | [connections.en.md](connections.en.md) | [connections.es.md](connections.es.md) | [connections.pt.md](connections.pt.md) |

Os nomes dos botões e das telas ficam em inglês nos três manuais, porque é o idioma da interface hoje.

## No Help Center

Os mesmos arquivos viram artigos do Help Center de cada conta, nos três idiomas:

```
docker compose exec rails bundle exec rails manual:import
```

Cada conta ganha o portal `manual-<id da conta>` com três categorias (Sales and CRM, AI, Channels) e um artigo por manual e idioma, **em rascunho**: só a equipe vê, em Help Center, e publica o que quiser. `ACCOUNT_ID=1` limita a uma conta. Rodar de novo atualiza o texto pelo repositório, sem duplicar e sem mudar o que já foi publicado. Manual novo ou corrigido: edite o arquivo, entre na imagem e rode o comando de novo. Um manual novo também entra na lista `MANUALS` de `app/services/manual/help_center_importer.rb`.

