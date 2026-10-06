# O cliente pediu para pagar a fatura pela página pública: confere o valor (de
# MINIMUM até o saldo; abaixo de MINIMUM, só o saldo inteiro) e a forma online,
# cria a tentativa e abre a sessão no provedor. O valor sai daqui, nunca da
# volta do provedor.
class Commerce::CheckoutStarter
  MINIMUM = 1

  def initialize(document, payment_method:, amount:, phone: nil)
    @document = document
    @payment_method = payment_method
    @phone = phone
    @amount = BigDecimal(amount.to_s).round(2)
  rescue ArgumentError
    @amount = nil
  end

  def start!(return_url)
    provider = @payment_method.provider
    raise Commerce::Gateways::Error, 'invalid payment' unless valid?(provider)

    # Se o provedor recusar (celular inválido, chave, moeda), não fica tentativa
    # pendente para trás.
    Commerce::Checkout.transaction do
      checkout = @document.account.commerce_checkouts.create!(document: @document, provider: provider, payment_method: @payment_method,
                                                              amount: @amount, currency: @document.currency)
      provider.gateway.start!(checkout, return_url: return_url, phone: @phone)
      checkout
    end
  end

  private

  def valid?(provider)
    return false unless @amount && @document.payable? && @payment_method.online? && provider.supports?(@document.currency)

    @amount.between?([MINIMUM, @document.balance].min, @document.balance)
  end
end
