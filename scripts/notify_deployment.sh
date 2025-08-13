#!/bin/bash -e
# Notifica sobre o deployment

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

DEPLOYMENT_ID=${DEPLOYMENT_ID:-"manual"}
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "localhost")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_info "Enviando notificação de deployment"

# Informações do deployment
echo "===== DEPLOYMENT CONCLUÍDO ====="
echo "Aplicação: $APP_NAME"
echo "Instância: $INSTANCE_ID"
echo "Deployment ID: $DEPLOYMENT_ID"
echo "Timestamp: $TIMESTAMP"
echo "Versão JAR: $(basename $(find_app_jar 2>/dev/null) || echo 'N/A')"
echo "Status do Serviço: $(systemctl is-active $SYSTEMD_SERVICE_NAME 2>/dev/null || echo 'N/A')"
echo "URL da Aplicação: http://${APP_HOST}:${APP_PORT}"
echo "============================="

# Aqui você pode adicionar integrações com:
# - Slack: curl -X POST -H 'Content-type: application/json' --data '{"text":"Deploy concluído!"}' $SLACK_WEBHOOK
# - Email: echo "Deploy concluído" | mail -s "Deploy $APP_NAME" admin@company.com
# - CloudWatch: aws logs put-log-events --log-group-name deployment-logs
# - SNS: aws sns publish --topic-arn arn:aws:sns:region:account:topic --message "Deploy concluído"

log_info "Notificação enviada"
