# Os textos que vão ao cliente sobre o caso, no idioma dele (es/pt/en), como o
# Commerce::DocumentLabels: fora do i18n da interface, porque o idioma é do
# cliente e não de quem usa a tela.
module Cases::CustomerLabels
  LANGUAGES = %w[es pt en].freeze
  TEXTS = {
    'es' => {
      opened: 'Registramos tu solicitud con el número %<number>s. El equipo ya la está revisando y te avisaremos cuando esté resuelta.',
      resolved: 'Tu solicitud %<number>s fue resuelta. Si necesitas algo más, escríbenos por aquí.'
    },
    'pt' => {
      opened: 'Registramos sua solicitação com o número %<number>s. A equipe já está cuidando dela e vamos avisar quando estiver resolvida.',
      resolved: 'Sua solicitação %<number>s foi resolvida. Se precisar de mais alguma coisa, é só escrever aqui.'
    },
    'en' => {
      opened: 'We logged your request as %<number>s. The team is already on it and we will let you know when it is resolved.',
      resolved: 'Your request %<number>s has been resolved. If you need anything else, just write here.'
    }
  }.freeze

  def self.normalize(language)
    code = language.to_s.split(/[-_]/).first.to_s.downcase
    LANGUAGES.include?(code) ? code : 'en'
  end

  def self.text(key, language, number:)
    format(TEXTS.fetch(normalize(language)).fetch(key), number: number)
  end
end
