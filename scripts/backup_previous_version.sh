#!/bin/bash -e
# Backup simples apenas para debug local (CodeDeploy já faz rollback automático)

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

log_info "Backup rápido para debug (CodeDeploy já gerencia rollback)"

# Backup apenas se existir JAR anterior E se diretório de backup existir
if [ -d "/opt/app/debug-backups" ] && ls ${APP_HOME}/app-*.jar >/dev/null 2>&1; then
    CURRENT_JAR=$(ls ${APP_HOME}/app-*.jar | head -n1)
    BACKUP_FILE="/opt/app/debug-backups/debug_$(date +%H%M%S).jar"
    
    cp "$CURRENT_JAR" "$BACKUP_FILE" 2>/dev/null || true
    log_info "Backup de debug criado: $(basename $BACKUP_FILE)"
    
    # Mantém apenas 1 backup (para não ocupar espaço)
    ls -t /opt/app/debug-backups/debug_*.jar 2>/dev/null | tail -n +2 | xargs rm -f 2>/dev/null || true
else
    log_info "Sem backup necessário (CodeDeploy gerencia rollback)"
fi
