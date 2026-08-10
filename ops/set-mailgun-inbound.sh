#!/bin/bash
# Liga a ENTRADA de e-mail: o Mailgun recebe a mensagem e a entrega no ingress
# do ActionMailbox. A saída continua pelo Resend, são coisas separadas.
#
# A chave de assinatura é digitada aqui: não aparece na tela, não entra no
# histórico do shell e não passa por log nenhum.
set -euo pipefail

ENV=/opt/cortexgen-chat/.env
DOMINIO="${1:-cortexgen.cloud}"
BACKUP="$ENV.bak-mailgun-$(date +%Y%m%d-%H%M%S)"
cp "$ENV" "$BACKUP"

# É a "HTTP webhook signing key" do Mailgun, não a API key de envio. O Rails
# valida a assinatura de cada POST com ela; errar a chave dá 401 no ingress e a
# mensagem some sem virar conversa.
read -rsp 'Mailgun HTTP webhook signing key: ' KEY
echo
if [ -z "${KEY}" ]; then
  echo 'Nada digitado — nada mudou.'
  exit 1
fi

set_kv() {
  if grep -q "^$1=" "$ENV"; then
    sed -i "s|^$1=.*|$1=$2|" "$ENV"
  else
    printf '%s=%s\n' "$1" "$2" >> "$ENV"
  fi
}

# Vazio não é o mesmo que ausente: `ENV.fetch('RAILS_INBOUND_EMAIL_SERVICE',
# 'relay')` devolve string vazia quando a variável existe em branco, e o Rails
# acaba com `ingress = :""` — nenhum ingress ativo e nenhum erro na tela.
set_kv RAILS_INBOUND_EMAIL_SERVICE mailgun
set_kv MAILGUN_INGRESS_SIGNING_KEY "$KEY"
set_kv MAILER_INBOUND_EMAIL_DOMAIN "$DOMINIO"

echo "Pronto. Backup do anterior em $BACKUP"
echo
grep -E '^(RAILS_INBOUND|MAILER_INBOUND|MAILGUN_INGRESS)' "$ENV" \
  | sed -E 's/^(MAILGUN_INGRESS_SIGNING_KEY)=.*/\1=***/'
