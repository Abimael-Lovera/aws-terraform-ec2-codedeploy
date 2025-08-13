#!/bin/bash -e
# Testes de fumaça pós-deployment

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

log_info "Executando smoke tests"

# Teste 1: Health Check
log_info "Teste 1: Health Check"
response=$(curl -s "$HEALTH_CHECK_URL" || echo "FAIL")
if [ "$response" != "OK" ]; then
    log_error "Health check falhou: $response"
    exit 1
fi
log_info "✅ Health check passou"

# Teste 2: Contador endpoint
log_info "Teste 2: Testando endpoint contador"
counter_url="http://${APP_HOST}:${APP_PORT}/contador"
for i in {1..3}; do
    count=$(curl -s "$counter_url" | grep -o '"count":[0-9]*' | cut -d: -f2 || echo "0")
    if [ "$count" -ge "$i" ]; then
        log_info "✅ Contador funcionando ($count)"
    else
        log_error "Contador não está incrementando corretamente"
        exit 1
    fi
    sleep 1
done

# Teste 3: Verifica logs de erro
log_info "Teste 3: Verificando logs de erro"
if [ -f "$APP_LOG_FILE" ]; then
    error_count=$(grep -c "ERROR\|Exception\|FATAL" "$APP_LOG_FILE" 2>/dev/null || echo "0")
    if [ "$error_count" -gt 0 ]; then
        log_warn "Encontrados $error_count erros nos logs"
        tail -n 10 "$APP_LOG_FILE"
    else
        log_info "✅ Nenhum erro encontrado nos logs"
    fi
fi

# Teste 4: Performance básica
log_info "Teste 4: Teste de performance básica"
start_time=$(date +%s%N)
curl -s "$HEALTH_CHECK_URL" >/dev/null
end_time=$(date +%s%N)
response_time=$(( (end_time - start_time) / 1000000 )) # em ms

if [ "$response_time" -lt 5000 ]; then # menos de 5 segundos
    log_info "✅ Tempo de resposta OK: ${response_time}ms"
else
    log_warn "Tempo de resposta alto: ${response_time}ms"
fi

log_info "Todos os smoke tests passaram!"
