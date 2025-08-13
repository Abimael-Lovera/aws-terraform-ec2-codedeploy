#!/bin/bash -e
# Valida se o serviço está saudável após o start

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

log_info "Validando serviço em $HEALTH_CHECK_URL"

# Verifica status do systemd se disponível
if systemctl list-unit-files | grep -q "^${SYSTEMD_SERVICE_NAME}.service" 2>/dev/null; then
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_info "Serviço systemd está ativo"
    else
        log_warn "Serviço systemd não está ativo"
        systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager || true
    fi
fi

# Validação via health check endpoint
for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" || true)
  if [ "$STATUS" = "200" ]; then
    log_info "Serviço saudável (tentativa $i)"
    exit 0
  fi
  log_warn "Ainda não saudável (HTTP $STATUS) tentativa $i/$HEALTH_CHECK_RETRIES"
  sleep $HEALTH_CHECK_SLEEP
done

log_error "Serviço não ficou saudável dentro do limite"

# Mostra logs para debug se systemd estiver disponível
if systemctl list-unit-files | grep -q "^${SYSTEMD_SERVICE_NAME}.service" 2>/dev/null; then
    log_info "Últimas linhas do log do serviço:"
    journalctl -u "$SYSTEMD_SERVICE_NAME" --no-pager --lines=10 || true
fi

exit 1
