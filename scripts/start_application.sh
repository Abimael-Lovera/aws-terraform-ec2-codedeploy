#!/bin/bash -e
# Inicia a aplicação Spring Boot usando systemd

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

# Encontra o JAR da aplicação
APP_JAR=$(find_app_jar)
if [ $? -ne 0 ]; then
    exit 1
fi

log_info "Iniciando aplicação via systemd: $SYSTEMD_SERVICE_NAME"

# Verifica se o serviço systemd existe
if systemctl list-unit-files | grep -q "^${SYSTEMD_SERVICE_NAME}.service"; then
    # Verifica se já está rodando
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_info "Serviço já está ativo"
        exit 0
    fi
    
    # Ajusta permissões do JAR
    log_info "Ajustando permissões do JAR: $APP_JAR"
    chown "${APP_USER}:${APP_GROUP}" "$APP_JAR" || true
    
    # Inicia o serviço
    log_info "Iniciando serviço systemd..."
    systemctl start "$SYSTEMD_SERVICE_NAME"
    
    # Aguarda inicialização
    timeout="$START_TIMEOUT"
    while [ $timeout -gt 0 ] && ! systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; do
        log_info "Aguardando serviço iniciar... (${timeout}s restantes)"
        sleep 1
        timeout=$((timeout - 1))
    done
    
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_info "Serviço iniciado com sucesso"
    else
        log_error "Falha ao iniciar serviço"
        systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager || true
        exit 1
    fi
else
    log_warn "Serviço systemd não encontrado, usando método manual..."
    
    # Fallback para método manual se systemd service não existir
    if is_app_running; then
        log_info "Aplicação já em execução"
        exit 0
    fi
    
    log_info "Ajustando permissões do JAR: $APP_JAR"
    chown "${APP_USER}:${APP_GROUP}" "$APP_JAR" || true
    
    log_info "Iniciando aplicação manual: $APP_JAR como $APP_USER"
    sudo -u "$APP_USER" nohup java -jar "$APP_JAR" > "$APP_LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    chown "${APP_USER}:${APP_GROUP}" "$PID_FILE" || true
    
    log_info "Aplicação iniciada (PID $(cat $PID_FILE))"
fi
