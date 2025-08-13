#!/bin/bash
# Script para testar as configurações globais

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

echo "=== Teste das Configurações Globais ==="
echo ""

echo "Configurações da Aplicação:"
echo "  APP_NAME: $APP_NAME"
echo "  APP_USER: $APP_USER"
echo "  APP_HOME: $APP_HOME"
echo "  APP_JAR_PATTERN: $APP_JAR_PATTERN"
echo ""

echo "Configurações de Sistema:"
echo "  JAVA_VERSION: $JAVA_VERSION"
echo "  SYSTEMD_SERVICE_NAME: $SYSTEMD_SERVICE_NAME"
echo ""

echo "Configurações de Rede:"
echo "  APP_HOST: $APP_HOST"
echo "  APP_PORT: $APP_PORT"
echo "  HEALTH_CHECK_URL: $HEALTH_CHECK_URL"
echo ""

echo "Configurações de Logs:"
echo "  APP_LOG_FILE: $APP_LOG_FILE"
echo "  INSTALL_LOG_FILE: $INSTALL_LOG_FILE"
echo "  PID_FILE: $PID_FILE"
echo ""

echo "Configurações de Validação:"
echo "  HEALTH_CHECK_RETRIES: $HEALTH_CHECK_RETRIES"
echo "  HEALTH_CHECK_SLEEP: $HEALTH_CHECK_SLEEP"
echo ""

echo "=== Testando Funções ==="
echo ""

echo "Testando função de logging:"
log_info "Esta é uma mensagem de info"
log_warn "Esta é uma mensagem de warning"
log_error "Esta é uma mensagem de erro"
echo ""

echo "Testando função de busca de JAR:"
if JAR_FOUND=$(find_app_jar 2>/dev/null); then
    echo "  JAR encontrado: $JAR_FOUND"
else
    echo "  JAR não encontrado (normal se não houve deploy ainda)"
fi
echo ""

echo "Testando função de verificação de usuário:"
if id -u "$APP_USER" >/dev/null 2>&1; then
    echo "  Usuário $APP_USER existe"
else
    echo "  Usuário $APP_USER não existe"
fi
echo ""

echo "Testando função de verificação de processo:"
if is_app_running; then
    echo "  Aplicação está rodando"
    if systemctl list-unit-files | grep -q "^${SYSTEMD_SERVICE_NAME}.service" 2>/dev/null; then
        if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
            echo "  Status systemd: ATIVO"
        else
            echo "  Status systemd: INATIVO"
        fi
    else
        echo "  Método: PID file (PID: $(cat $PID_FILE 2>/dev/null || echo 'N/A'))"
    fi
else
    echo "  Aplicação não está rodando"
fi
echo ""

echo "Testando configurações do systemd:"
echo "  SYSTEMD_SERVICE_NAME: $SYSTEMD_SERVICE_NAME"
echo "  SYSTEMD_SERVICE_FILE: $SYSTEMD_SERVICE_FILE"
if systemctl list-unit-files | grep -q "^${SYSTEMD_SERVICE_NAME}.service" 2>/dev/null; then
    echo "  Serviço systemd: EXISTE"
    echo "  Status: $(systemctl is-active $SYSTEMD_SERVICE_NAME 2>/dev/null || echo 'DESCONHECIDO')"
    echo "  Habilitado: $(systemctl is-enabled $SYSTEMD_SERVICE_NAME 2>/dev/null || echo 'DESCONHECIDO')"
else
    echo "  Serviço systemd: NÃO EXISTE"
fi
echo ""

echo "=== Teste Concluído ==="
