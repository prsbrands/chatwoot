#!/bin/bash
# Configura o formulário público de "peça uma demo" (site → n8n → Rails):
# gera o segredo compartilhado que autentica o n8n nesse endpoint, e diz de
# qual número/persona a ligação de demo sai.
#
# O token é gerado aqui, aparece uma única vez no fim para você colar na
# credential do n8n (tipo "Header Auth", header Authorization, valor
# "Bearer <token>") — não passa por chat nem fica em nenhum log. Faz backup
# do .env antes de mexer.
set -euo pipefail

ENV_FILE=/opt/cortexgen-chat/.env
BACKUP="$ENV_FILE.bak-voice-demo-$(date +%Y%m%d-%H%M%S)"
cp "$ENV_FILE" "$BACKUP"

read -rp 'Número que faz a ligação de demo (E.164, ex: +551150289898): ' ROUTE_NUMBER
if [ -z "${ROUTE_NUMBER}" ]; then
  echo 'Nada digitado — nada mudou.'
  exit 1
fi
case "$ROUTE_NUMBER" in
  +*) ;;
  *) echo 'Precisa começar com + e o código do país (E.164). Nada mudou.'; exit 1 ;;
esac

read -rp 'Slug da persona de demo [nathan-demo-br]: ' PERSONA_SLUG
PERSONA_SLUG="${PERSONA_SLUG:-nathan-demo-br}"

TOKEN=$(openssl rand -hex 32)

set_kv() {
  if grep -q "^$1=" "$ENV_FILE"; then
    sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE"
  fi
}

set_kv PUBLIC_VOICE_REQUEST_TOKEN "$TOKEN"
set_kv PUBLIC_VOICE_DEMO_ROUTE_NUMBER "$ROUTE_NUMBER"
set_kv PUBLIC_VOICE_DEMO_PERSONA_SLUG "$PERSONA_SLUG"

echo "Pronto. Backup do anterior em $BACKUP"
echo
echo 'Lembrete: mudança no .env exige `docker compose up -d --force-recreate rails sidekiq` pra valer.'
echo
echo 'Cole isto na credential do n8n (Header Auth — header "Authorization"), e não em outro lugar:'
echo "Bearer $TOKEN"
