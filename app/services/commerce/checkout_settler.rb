# Aplica a resposta do provedor a uma tentativa de pagamento, venha ela do
# webhook, da volta do cliente ou da conciliação. Pago vira pagamento da fatura
# uma vez só (checkout travado + checkout_id único no pagamento), no valor que o
# provedor confirmou; o recibo e a nota na conversa saem pelo Commerce::ReceiptJob.
class Commerce::CheckoutSettler
  def initialize(checkout)
    @checkout = checkout
  end

  # Pergunta ao provedor; a tentativa que passou do prazo sem pagar expira.
  def refresh!
    result = @checkout.provider.gateway.status(@checkout)
    result = { status: :expired } if result[:status] == :pending && @checkout.created_at < Commerce::Checkout::EXPIRES_IN.ago
    apply!(result)
  end

  def apply!(result)
    payment = @checkout.with_lock do
      next if @checkout.paid?

      if result[:status] == :paid
        pay!(result)
      elsif %i[failed expired].include?(result[:status])
        @checkout.update!(status: result[:status])
        nil
      end
    end
    Commerce::ReceiptJob.perform_later(payment.id, notify: true) if payment
  end

  private

  def pay!(result)
    payment = Commerce::DocumentFlow.new(@checkout.document).add_payment!(
      amount: result[:amount], paid_on: Date.current, payment_method: @checkout.payment_method, checkout: @checkout,
      note: [@checkout.payment_method&.name, result[:reference]].compact.join(' · ')
    )
    @checkout.update!(status: :paid, paid_at: Time.current, payload: result.as_json)
    payment
  end
end
