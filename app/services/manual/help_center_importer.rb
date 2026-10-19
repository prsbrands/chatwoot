# Põe os manuais de docs/manual (um arquivo por recurso e idioma) no Help Center
# de uma conta: um portal "manual-<conta>" com en, es e pt_BR, três categorias e
# um artigo por manual e idioma. Os artigos novos entram como rascunho (só os
# agentes veem, no painel); quem publica é a equipe. Rodar de novo atualiza o
# título e o texto pelo repositório e não mexe no estado nem duplica nada.
#
#   bundle exec rails manual:import               # todas as contas
#   ACCOUNT_ID=1 bundle exec rails manual:import  # uma conta
class Manual::HelpCenterImporter
  DIR = Rails.root.join('docs/manual')
  # Sufixo do arquivo -> locale do Help Center.
  LOCALES = { 'en' => 'en', 'es' => 'es', 'pt' => 'pt_BR' }.freeze
  PORTAL_NAMES = { 'en' => 'User manual', 'es' => 'Manual de uso', 'pt_BR' => 'Manual de uso' }.freeze
  CATEGORIES = {
    'sales' => { 'en' => 'Sales and CRM', 'es' => 'Ventas y CRM', 'pt_BR' => 'Vendas e CRM' },
    'ai' => { 'en' => 'AI', 'es' => 'IA', 'pt_BR' => 'IA' },
    'channels' => { 'en' => 'Channels', 'es' => 'Canales', 'pt_BR' => 'Canais' }
  }.freeze
  # Ordem e categoria de cada manual.
  MANUALS = {
    'funil' => 'sales', 'casos' => 'sales', 'agenda' => 'sales', 'outreach' => 'sales',
    'comercial-catalogo' => 'sales', 'comercial-documentos' => 'sales', 'comercial-cobranca' => 'sales', 'comercial-vitrine' => 'sales',
    'memoria-ia' => 'ai', 'evolucao-ia' => 'ai',
    'connections' => 'channels'
  }.freeze
  # A linha "Also in: [Español](x.es.md)" não serve no portal, que já tem o seletor de idioma.
  OTHER_LANGUAGES = /^\*(?:Also in|También en|Também em):.*\*[ \t]*\n?/
  MANUAL_LINK = /\]\(([\w-]+)\.(en|es|pt)\.md(#[\w-]*)?\)/

  def initialize(account)
    @account = account
  end

  # Quantos artigos e categorias foram criados ou atualizados, ou nil quando a
  # conta não tem administrador para assinar os artigos.
  def perform
    author = @account.administrators.first
    return if author.nil?

    portal = ensure_portal
    categories = ensure_categories(portal)
    articles = import_articles(portal, categories, author)
    { portal: portal.slug, categories: categories.values.sum(&:size), articles: articles }
  end

  private

  def ensure_portal
    portal = @account.portals.find_or_initialize_by(slug: "manual-#{@account.id}")
    portal.name ||= PORTAL_NAMES['en']
    portal.config = (portal.config || {}).merge('allowed_locales' => LOCALES.values, 'default_locale' => 'en')
    portal.save!
    portal
  end

  # { 'sales' => { 'en' => Category, 'es' => ..., 'pt_BR' => ... }, ... }; as
  # outras línguas apontam para a categoria em inglês.
  def ensure_categories(portal)
    CATEGORIES.each_with_index.to_h do |(slug, names), position|
      root = nil
      by_locale = LOCALES.values.to_h do |locale|
        category = portal.categories.find_or_initialize_by(slug: slug, locale: locale)
        category.update!(account: @account, name: names[locale], position: position + 1, associated_category_id: root&.id)
        root ||= category
        [locale, category]
      end
      [slug, by_locale]
    end
  end

  def import_articles(portal, categories, author)
    MANUALS.each_with_index.sum do |(key, category_key), position|
      root = nil
      LOCALES.each do |suffix, locale|
        article = import_article(portal, categories.dig(category_key, locale), author, [key, suffix, position + 1], root)
        root ||= article
      end
      LOCALES.size
    end
  end

  def import_article(portal, category, author, (key, suffix, position), root)
    title, content = read(key, suffix)
    article = portal.articles.find_or_initialize_by(slug: slug_for(key, suffix))
    article.assign_attributes(account: @account, author: author, category: category, title: title, content: content,
                              associated_article_id: root&.id)
    article.assign_attributes(position: position, status: :draft) if article.new_record?
    article.save!
    article
  end

  def slug_for(key, suffix)
    "manual-#{@account.id}-#{key}-#{LOCALES.fetch(suffix).downcase}"
  end

  # Título é a primeira linha ("# ..."); os links entre manuais viram links
  # entre os artigos do portal.
  def read(key, suffix)
    first, *rest = DIR.join("#{key}.#{suffix}.md").read.lines
    body = rest.join.sub(OTHER_LANGUAGES, '').gsub(MANUAL_LINK) do
      "](/hc/manual-#{@account.id}/articles/#{slug_for(Regexp.last_match(1), Regexp.last_match(2))}#{Regexp.last_match(3)})"
    end
    [first.sub(/\A#\s+/, '').strip, body.strip]
  end
end
