# Provedores de cobrança online (Commerce::Gateways::Stripe e ::MercadoPago;
# Yappy na próxima fase). Todos respondem a connect!, start!, status e
# webhook(request), e devolvem o resultado como { status:, amount:, reference: };
# o webhook devolve também como achar o checkout ({ external_id: } ou { id: }).
module Commerce::Gateways
  # Recusa do provedor (chave inválida, moeda não aceita, rede): vira mensagem.
  class Error < StandardError; end
  # Aviso de webhook sem assinatura válida: 400, nada é gravado.
  class InvalidSignature < StandardError; end
end
