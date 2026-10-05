# Busca do comercial sem diferenciar acento nem maiúscula ("maria" acha
# "María"), com o translate do Postgres nos dois lados — sem extensão no banco.
module Commerce::Search
  FROM = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ'.freeze
  TO = 'aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn'.freeze

  def self.where(scope, expressions, query)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(I18n.transliterate(query.to_s.strip).downcase)}%"
    sql = expressions.map { |expression| "lower(translate(#{expression}, '#{FROM}', '#{TO}')) LIKE :term" }.join(' OR ')
    scope.where(sql, term: term)
  end
end
