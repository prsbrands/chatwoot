# Põe a lista lida (Outreach::Sheet) na campanha. O telefone é a coluna
# mapeada, normalizada para E.164 com o código do país da lista; o que não dá
# para normalizar fica como veio e a preparação o marca `invalid_phone`. Todas
# as colunas viram variável da mensagem pelo título sem acento (`{telefone}`,
# `{cidade}`), e a coluna "company" mapeada vira `{company}`. Quem nunca for
# enviado não vira contato: a linha fica só na campanha.
class Outreach::Importer
  def initialize(campaign, sheet, mapping, country: Outreach::Phone::DEFAULT_COUNTRY)
    @campaign = campaign
    @sheet = sheet
    @mapping = mapping
    @country = country
  end

  def perform
    rows = @sheet.rows.map { |line| attributes(line) }
    Outreach::Recipient.transaction do
      @campaign.recipients.delete_all
      rows.each_slice(1000) { |slice| Outreach::Recipient.insert_all(slice) } # rubocop:disable Rails/SkipsModelValidations
      @campaign.update!(audience: { 'source' => 'import', 'mapping' => @mapping, 'country' => @country, 'count' => rows.size })
    end
    rows.size
  end

  private

  def attributes(line)
    cells = @sheet.headers.zip(line).to_h
    raw = cells[@mapping['phone']].to_s
    variables = slugs.zip(line).to_h.compact_blank
    variables['company'] = cells[@mapping['company']] if @mapping['company'].present?
    {
      account_id: @campaign.account_id,
      campaign_id: @campaign.id,
      phone: Outreach::Phone.normalize(raw, country: @country) || raw,
      name: cells[@mapping['name']].presence,
      variables: variables.compact_blank
    }
  end

  # Títulos sem acento e sem símbolo; repetido ganha "_2", "_3".
  def slugs
    @slugs ||= begin
      seen = Hash.new(0)
      @sheet.headers.map do |title|
        slug = I18n.transliterate(title).downcase.gsub(/[^a-z0-9]+/, '_').gsub(/\A_|_\z/, '').presence || 'column'
        seen[slug] += 1
        seen[slug] > 1 ? "#{slug}_#{seen[slug]}" : slug
      end
    end
  end
end
