#!/bin/bash -eux
# Para a aplicação Spring Boot usando systemd

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

log_info "Parando aplicação via systemd: $SYSTEMD_SERVICE_NAME"

# Verifica se o serviço existe
if systemctl list-unit-files | grep -q "^${SYSTEMD_SERVICE_NAME}.service"; then
    # Verifica se está ativo
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_info "Serviço está ativo, parando..."
        systemctl stop "$SYSTEMD_SERVICE_NAME"
        
        # Aguarda até parar completamente
        timeout="$STOP_TIMEOUT"
        while [ $timeout -gt 0 ] && systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; do
            log_info "Aguardando serviço parar... (${timeout}s restantes)"
            sleep 1
            timeout=$((timeout - 1))
        done
        
        if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
            log_warn "Serviço não parou no tempo esperado, forçando..."
            systemctl kill --signal=SIGKILL "$SYSTEMD_SERVICE_NAME"
        else
            log_info "Serviço parado com sucesso"
        fi
    else
        log_info "Serviço já estava parado"
    fi
else
    log_warn "Serviço systemd não encontrado, tentando método manual..."
    
    # Fallback para método manual se systemd service não existir
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            log_info "Parando aplicação manual (PID $PID)"
            kill "$PID"
            sleep 5
            if kill -0 "$PID" 2>/dev/null; then
                log_warn "Forçando término"
                kill -9 "$PID"
            fi
        fi
        rm -f "$PID_FILE"
    else
        log_info "Nenhum processo encontrado para parar"
    fi
fi
