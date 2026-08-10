#!/bin/bash
# Aponta o SMTP do Chatwoot para o Resend.
#
# A chave é digitada aqui, não aparece na tela, não entra no histórico do shell
# e não passa por nenhum log. Faz backup do .env antes de mexer.
set -euo pipefail

ENV=/opt/cortexgen-chat/.env
BACKUP="$ENV.bak-resend-$(date +%Y%m%d-%H%M%S)"
cp "$ENV" "$BACKUP"

read -rsp 'Resend API key (re_...): ' KEY
echo
if [ -z "${KEY}" ]; then
  echo 'Nada digitado — nada mudou.'
  exit 1
fi
case "$KEY" in
  re_*) ;;
  *) echo 'Isso não parece uma chave do Resend (começa com re_). Nada mudou.'; exit 1 ;;
esac

set_kv() {
  # O delimitador é | porque a chave do Resend não contém esse caractere.
  if grep -q "^$1=" "$ENV"; then
    sed -i "s|^$1=.*|$1=$2|" "$ENV"
  else
    printf '%s=%s\n' "$1" "$2" >> "$ENV"
  fi
}

set_kv SMTP_ADDRESS smtp.resend.com
set_kv SMTP_PORT 465
set_kv SMTP_USERNAME resend
set_kv SMTP_PASSWORD "$KEY"
set_kv SMTP_AUTHENTICATION plain
set_kv SMTP_TLS true
set_kv SMTP_ENABLE_STARTTLS_AUTO false

# O domínio verificado no Resend é o cortexgen.cloud — é dele que sai o DKIM que
# alinha o DMARC. Enviar como @prsbrands.com por aqui seria remetente sem
# assinatura, que é o caminho curto para a pasta de spam num e-mail de reset de
# senha. O remetente muda junto, de propósito.
set_kv SMTP_DOMAIN cortexgen.cloud
set_kv MAILER_SENDER_EMAIL 'CortexGen Chat <no-reply@cortexgen.cloud>'

echo "Pronto. Backup do anterior em $BACKUP"
echo
echo 'Conferência (a chave fica mascarada):'
grep -E '^(SMTP_|MAILER_SENDER)' "$ENV" | sed -E 's/^(SMTP_PASSWORD)=.*/\1=***/'
