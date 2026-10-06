# Provedores de cobrança online (Commerce::Gateways::Stripe; Mercado Pago e
# Yappy nas próximas fases). Todos respondem a connect!, start!, status e
# webhook, e devolvem o resultado como { status:, amount:, reference: }.
module Commerce::Gateways
  # Recusa do provedor (chave inválida, moeda não aceita, rede): vira mensagem.
  class Error < StandardError; end
  # Aviso de webhook sem assinatura válida: 400, nada é gravado.
  class InvalidSignature < StandardError; end
end
