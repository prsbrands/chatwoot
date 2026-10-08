#!/usr/bin/env bash
# Roda os testes do funil (blocos 3a/3b/3c) contra Postgres e Redis
# DESCARTAVEIS, com a imagem que vai subir. Nunca toca no banco nem no Redis da
# producao (jobs do teste iriam para o sidekiq real).
#
#   na VPS, de dentro de /opt/cortexgen-chat:
#   bash <clone>/ops/smoke/run.sh cortexgen-chat:test-bN <clone>/ops/smoke
#
# Cada script imprime "OK <cenario>" ou "FALHOU <cenario>".
set -u
IMAGE=$1
DIR=$2
N=cortexgen-chat_default
docker rm -f sales-pg sales-redis >/dev/null 2>&1 || true
docker run -d --name sales-pg --network $N -e POSTGRES_PASSWORD=t -e POSTGRES_DB=sales_test pgvector/pgvector:pg16 >/dev/null
docker run -d --name sales-redis --network $N redis:alpine >/dev/null
for _ in $(seq 1 20); do docker exec sales-pg pg_isready -U postgres -q && break; sleep 1; done
E="--network $N --env-file .env -e RAILS_ENV=production -e NODE_ENV=production -e INSTALLATION_ENV=docker
   -e POSTGRES_HOST=sales-pg -e POSTGRES_DATABASE=sales_test -e POSTGRES_USERNAME=postgres -e POSTGRES_PASSWORD=t
   -e REDIS_URL=redis://sales-redis:6379 -e REDIS_PASSWORD= -e DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
docker run --rm $E --entrypoint bundle "$IMAGE" exec rails db:schema:load >/dev/null 2>&1
for t in sales_pipeline sales_stage_advisor sales_insights sales_radar sales_tasks agenda agenda_slots agenda_ai agenda_cycle ai_usage commerce commerce_documents commerce_checkout commerce_mercado_pago commerce_yappy commerce_subscriptions commerce_subscriptions_mp commerce_subscriptions_yappy commerce_ai commerce_storefront ai_memory; do
  out=$(docker run --rm $E -v "$DIR/$t.rb:/tmp/t.rb" --entrypoint bundle "$IMAGE" exec rails runner /tmp/t.rb 2>&1)
  echo "== $t: $(echo "$out" | grep -c '^OK') OK, $(echo "$out" | grep -c '^FALHOU') falhas"
  echo "$out" | grep -E '^FALHOU|t.rb:[0-9]+' | head -5
done
docker rm -f sales-pg sales-redis >/dev/null
