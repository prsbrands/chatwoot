# O texto de uma pessoa da campanha: a variação da vez, as opções `{Oi|Olá}`
# sorteadas, as variáveis `{name}`, `{full_name}` e as colunas da lista
# trocadas, o rodapé de saída e a divisão em bolhas. Variável sem valor deixa a
# pessoa de fora (`missing`), como no DeskComm: melhor não mandar do que mandar
# "Olá {name}".
class Outreach::Message
  MAX_BUBBLES = 4
  SPIN = /\{([^{}|]+(?:\|[^{}|]*)+)\}/
  VARIABLE = /\{([a-z0-9_]+)\}/

  def initialize(campaign, recipient)
    @campaign = campaign
    @recipient = recipient
  end

  # As variáveis do texto que a pessoa não tem. Sem variação escolhida ainda
  # (na preparação da lista), vale para qualquer uma das variações.
  def missing
    texts = @recipient.variant ? [variant_text] : @campaign.variants
    texts.flat_map { |text| text.gsub(SPIN, '').scan(VARIABLE).flatten }.uniq.select { |name| values[name].blank? }
  end

  # Exige a variação da pessoa escolhida (`recipient.variant`).
  def bubbles
    body = variant_text.gsub(SPIN) { Regexp.last_match(1).split('|', -1).sample }
    body = body.gsub(VARIABLE) { values[Regexp.last_match(1)].to_s }
    body = "#{body}\n\n#{@campaign.opt_out_footer.strip}" if @campaign.opt_out_footer.present?
    split(body)
  end

  private

  def variant_text
    @campaign.variants[@recipient.variant]
  end

  def values
    @values ||= @recipient.variables.merge('name' => @recipient.first_name, 'full_name' => @recipient.name).compact_blank
  end

  # Um parágrafo por bolha (linha em branco separa), sem partir lista e sem separar
  # a frase que termina em ":" do que ela apresenta; o que passa de MAX_BUBBLES
  # vai junto na última.
  def split(body)
    joined = paragraphs(body).each_with_object([]) do |paragraph, bubbles|
      previous = bubbles.last
      if previous && (previous.end_with?(':') || (list_item?(paragraph) && list_item?(previous.lines.last)))
        bubbles[-1] = "#{previous}\n\n#{paragraph}"
      else
        bubbles << paragraph
      end
    end
    joined.push(joined.pop(joined.size - MAX_BUBBLES + 1).join("\n\n")) if joined.size > MAX_BUBBLES
    joined
  end

  def paragraphs(body)
    body.split(/\n[ \t]*\n/).map(&:strip).compact_blank
  end

  def list_item?(line)
    line.to_s.match?(/\A\s*([-*•]|\d+[.)])\s/)
  end
end
