# Telefone no formato que o WhatsApp e o Chatwoot aceitam (E.164 com "+"). Sem o
# "+" e sem o "00", até 8 dígitos é número local e leva o código do país da
# lista (Panamá, 507, por padrão); com mais dígitos só vale se já começar pelo
# código. O resto é inválido: chutar o país de um número comprido mandaria a
# mensagem para outra pessoa.
module Outreach::Phone
  DEFAULT_COUNTRY = '507'.freeze
  E164 = /\A\+[1-9]\d{7,14}\z/

  def self.normalize(raw, country: DEFAULT_COUNTRY)
    text = raw.to_s.strip
    number = with_country(text, text.gsub(/\D/, ''), country)
    "+#{number}" if number && "+#{number}".match?(E164)
  end

  def self.with_country(text, digits, country)
    return digits if text.start_with?('+')
    return digits[2..] if digits.start_with?('00')
    return "#{country}#{digits}" if digits.length <= 8

    digits if digits.start_with?(country)
  end
end
