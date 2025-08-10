#!/bin/bash -e
# Valida se o serviço está saudável após o start

HOST=localhost
PORT=${PORT:-8080}
RETRIES=15
SLEEP=2
URL="http://$HOST:$PORT/healthcheck"

echo "[INFO] Validando serviço em $URL"

for i in $(seq 1 $RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || true)
  if [ "$STATUS" = "200" ]; then
    echo "[INFO] Serviço saudável (tentativa $i)"
    exit 0
  fi
  echo "[WARN] Ainda não saudável (HTTP $STATUS) tentativa $i/$RETRIES"
  sleep $SLEEP
done

echo "[ERROR] Serviço não ficou saudável dentro do limite"
exit 1
