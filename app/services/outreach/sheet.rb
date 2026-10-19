# Lê a lista enviada: CSV, XLSX ou ODS (o Excel antigo, XLS, precisa de uma
# biblioteca GPL e fica de fora: salve como XLSX ou CSV). A primeira linha são
# os títulos das colunas. Devolve tudo como texto; número de telefone que a
# planilha guardou como número vira dígitos, sem ".0".
class Outreach::Sheet
  Invalid = Class.new(StandardError)
  Result = Struct.new(:headers, :rows)

  MAX_ROWS = 10_000
  EXTENSIONS = %w[csv xlsx ods].freeze

  def self.read(file)
    new(file).read
  end

  def initialize(file)
    @path = file.path
    @extension = File.extname(file.original_filename.to_s).delete('.').downcase
  end

  def read
    raise Invalid, "unsupported file type (use #{EXTENSIONS.join(', ')})" unless EXTENSIONS.include?(@extension)

    lines = @extension == 'csv' ? csv_lines : sheet_lines
    raise Invalid, 'the file has no rows' if lines.size < 2
    raise Invalid, "the file has more than #{MAX_ROWS} rows" if lines.size - 1 > MAX_ROWS

    Result.new(headers_of(lines.first), rows_of(lines.drop(1)))
  rescue Zip::Error, Nokogiri::XML::SyntaxError, CSV::MalformedCSVError, ArgumentError, TypeError
    raise Invalid, 'the file could not be read'
  end

  private

  # CSV do Excel em português usa ";" no lugar de ",".
  def csv_lines
    first = File.open(@path, 'r:bom|utf-8', &:gets).to_s
    CSV.read(@path, encoding: 'bom|utf-8', col_sep: first.count(';') > first.count(',') ? ';' : ',')
  end

  def sheet_lines
    sheet = @extension == 'xlsx' ? Roo::Excelx.new(@path, file_warning: :ignore) : Roo::OpenOffice.new(@path, file_warning: :ignore)
    return [] if sheet.last_row.nil?

    (sheet.first_row..sheet.last_row).map { |index| sheet.row(index) }
  end

  def headers_of(line)
    line.each_with_index.map { |title, index| text(title).presence || "column_#{index + 1}" }
  end

  def rows_of(lines)
    lines.map { |line| line.map { |cell| text(cell) } }.reject { |line| line.all?(&:blank?) }
  end

  def text(cell)
    cell = cell.to_i if cell.is_a?(Float) && cell == cell.floor
    cell.to_s.strip
  end
end
