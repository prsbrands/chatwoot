#!/bin/bash
# Liga o Cloudflare RealtimeKit (o card "Dyte" do Chatwoot) na conta 1.
#
# O token e digitado aqui: nao aparece na tela, nao entra no historico do shell
# e nao passa por linha de comando — vai por arquivo com permissao 600, lido e
# apagado dentro do container.
#
# Onde achar cada valor, no painel da Cloudflare:
#   account_id  Realtime > qualquer pagina, na URL ou na barra lateral
#   app_id      Realtime > RealtimeKit > o app criado
#   api_token   um API Token com permissao de RealtimeKit
set -euo pipefail
cd /opt/cortexgen-chat

read -rp  'Cloudflare account_id: ' ACCOUNT_ID
read -rp  'RealtimeKit app_id   : ' APP_ID
read -rsp 'API token            : ' API_TOKEN
echo

for v in "$ACCOUNT_ID" "$APP_ID" "$API_TOKEN"; do
  [ -n "$v" ] || { echo 'Faltou um valor — nada mudou.'; exit 1; }
done

ARQUIVO=$(mktemp)
chmod 600 "$ARQUIVO"
trap 'rm -f "$ARQUIVO"' EXIT
printf '{"account_id":"%s","app_id":"%s","api_token":"%s"}\n' "$ACCOUNT_ID" "$APP_ID" "$API_TOKEN" > "$ARQUIVO"

docker cp "$ARQUIVO" cortexgen-chat-rails-1:/tmp/rtk.json >/dev/null

docker compose exec -T rails bundle exec rails runner '
  require "json"
  caminho = "/tmp/rtk.json"
  dados = JSON.parse(File.read(caminho))
  File.delete(caminho)

  conta = Account.find(1)
  hook = Integrations::Hook.find_or_initialize_by(account: conta, app_id: "dyte")
  hook.settings = dados
  hook.status = :enabled
  hook.save!
  puts "hook gravado: ##{hook.id} status=#{hook.status}"

  # Prova de fogo: cria uma reuniao de verdade na Cloudflare. Credencial errada
  # falha aqui, e nao com um agente tentando ligar para um cliente.
  cliente = Dyte.new(dados["account_id"], dados["app_id"], dados["api_token"])
  r = cliente.create_a_meeting("teste de conexao")
  if r[:error].present?
    puts "TESTE FALHOU: #{r[:error]}"
  else
    puts "TESTE OK: reuniao criada, id=#{r.dig(:data, :id) || r[:id] || r.inspect[0, 120]}"
  end
' 2>&1 | grep -vE "^(I|W|D), \[|Sidekiq|RubyLLM|^$"
