# Manuais no Help Center (Manual::HelpCenterImporter, rails manual:import): um
# portal por conta com en, es e pt_BR, categorias, artigos em rascunho ligados
# entre os idiomas, links entre manuais reescritos, e rodar de novo sem duplicar,
# contra Postgres/Redis descartáveis.
def ok(nome, cond) = puts("#{cond ? 'OK ' : 'FALHOU'} #{nome}")

total = Manual::HelpCenterImporter::MANUALS.size * Manual::HelpCenterImporter::LOCALES.size
account = Account.create!(name: 'Manual', locale: 'en')
vazia = Account.create!(name: 'Sem admin', locale: 'en')
admin = User.create!(name: 'Ana Admin', email: "ana-#{SecureRandom.hex(3)}@man.test", password: 'Senha-forte-1!', confirmed_at: Time.current)
AccountUser.create!(account: account, user: admin, role: :administrator)

ok 'conta sem administrador é pulada', Manual::HelpCenterImporter.new(vazia).perform.nil? && vazia.portals.none?

resultado = Manual::HelpCenterImporter.new(account).perform
portal = account.portals.find_by!(slug: "manual-#{account.id}")
ok 'resultado: portal, 9 categorias e um artigo por manual e idioma', resultado == { portal: portal.slug, categories: 9, articles: total } && total == 33
ok 'portal com os três idiomas, inglês como padrão', portal.config['allowed_locales'].sort == %w[en es pt_BR] && portal.config['default_locale'] == 'en'
ok 'categorias: 3 por idioma, as outras línguas ligadas à de inglês',
   portal.categories.count == 9 && portal.categories.where(locale: 'es').all? { |c| c.associated_category_id == portal.categories.find_by!(slug: c.slug, locale: 'en').id }
ok 'artigos em rascunho, assinados pelo administrador', portal.articles.count == total && portal.articles.all? { |a| a.draft? && a.author_id == admin.id }

funil_en = portal.articles.find_by!(slug: "manual-#{account.id}-funil-en")
funil_pt = portal.articles.find_by!(slug: "manual-#{account.id}-funil-pt_br")
ok 'artigo em inglês: título da primeira linha, na categoria do idioma', funil_en.title.present? && !funil_en.title.start_with?('#') && funil_en.locale == 'en' && funil_en.category.slug == 'sales'
ok 'artigo em português ligado ao de inglês, locale pt_BR', funil_pt.locale == 'pt_BR' && funil_pt.associated_article_id == funil_en.id
ok 'sem a linha "Also in" nem links para arquivos .md',
   portal.articles.none? { |a| a.content.match?(/Also in:|También en:|Também em:|\]\([\w-]+\.(en|es|pt)\.md/) }
cobranca = portal.articles.find_by!(slug: "manual-#{account.id}-comercial-catalogo-en")
ok 'link entre manuais vira link do portal',
   cobranca.content.include?("](/hc/manual-#{account.id}/articles/manual-#{account.id}-comercial-cobranca-en)")

# Rodar de novo: não duplica, atualiza o texto, respeita o estado
funil_en.update!(status: :published, content: 'texto editado')
again = Manual::HelpCenterImporter.new(account).perform
ok 'de novo: nada duplicado', again[:articles] == total && portal.reload.articles.count == total && portal.categories.count == 9 && account.portals.count == 1
funil_en.reload
ok 'de novo: o texto volta ao do repositório e a publicação é mantida', funil_en.published? && funil_en.content != 'texto editado' && funil_en.content.size > 500

# Outra conta tem o próprio portal e os próprios artigos
outra = Account.create!(name: 'Outra', locale: 'en')
AccountUser.create!(account: outra, user: admin, role: :administrator)
Manual::HelpCenterImporter.new(outra).perform
ok 'outra conta: portal e artigos próprios, sem conflito de slug', outra.portals.first.slug == "manual-#{outra.id}" && outra.portals.first.articles.count == total &&
                                                                  Article.where(slug: "manual-#{outra.id}-funil-en").count == 1
