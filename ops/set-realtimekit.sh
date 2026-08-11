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

# Diagnostico antes de gravar. O Chatwoot valida as credenciais no `save!` e,
# quando reprova, so diz "token invalido" — sem dizer o que a Cloudflare
# respondeu. Estas duas chamadas sao as mesmas que ele faz, com a resposta crua
# na tela, para a proxima tentativa ser informada em vez de as cegas.
echo
echo '--- 1. o token e valido e esta ativo? ---'
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $API_TOKEN" \
  | python3 -c 'import json,sys
r = json.load(sys.stdin)
print("  success:", r.get("success"), "| status:", (r.get("result") or {}).get("status"))
for e in r.get("errors") or []:
    print("  erro", e.get("code"), "-", e.get("message"))'

echo
echo '--- 2. o app_id existe nesta conta? ---'
curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/realtime/kit/apps" \
  -H "Authorization: Bearer $API_TOKEN" \
  | python3 -c "import json,sys
r = json.load(sys.stdin)
apps = r.get('data') or []
if not r.get('success', True) or r.get('errors'):
    for e in r.get('errors') or []:
        print('  erro', e.get('code'), '-', e.get('message'))
print('  apps encontrados:', [a.get('id') for a in apps] or 'nenhum')
print('  o app_id informado esta na lista:', any(a.get('id') == '$APP_ID' for a in apps))"

echo
echo '--- 3. gravando o hook ---'
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

  # Sem `save!`: a validacao do Chatwoot ja reprova credencial errada, e um
  # stack trace de 30 linhas esconde a unica linha que interessa.
  if hook.save
    puts "  hook gravado: ##{hook.id} status=#{hook.status}"

    # Prova de fogo: cria uma reuniao de verdade. Credencial que passa na
    # validacao mas nao cria reuniao falharia com um agente na linha.
    cliente = Dyte.new(dados["account_id"], dados["app_id"], dados["api_token"])
    r = cliente.create_a_meeting("teste de conexao")
    if r[:error].present?
      puts "  TESTE FALHOU: #{r[:error]}"
    else
      puts "  TESTE OK: reuniao criada, id=#{r.dig(:data, :id) || r[:id] || r.inspect[0, 120]}"
    end
  else
    puts "  NAO GRAVOU: #{hook.errors.full_messages.join(%q(; ))}"
  end
' 2>&1 | grep -vE "^(I|W|D), \[|Sidekiq|RubyLLM|^$"
