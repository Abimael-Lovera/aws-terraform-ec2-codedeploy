#!/bin/bash -e
# Cria/atualiza unidade systemd para a aplicação

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

# Encontra o JAR da aplicação
APP_JAR=$(find_app_jar)
if [ $? -ne 0 ]; then
    exit 1
fi

log_info "Criando/atualizando serviço systemd: $SYSTEMD_SERVICE_NAME"

cat > "$SYSTEMD_SERVICE_FILE" <<EOF
[Unit]
Description=$SYSTEMD_DESCRIPTION
After=$SYSTEMD_AFTER
StartLimitIntervalSec=0

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_HOME
ExecStart=/usr/bin/java -jar $APP_JAR
Restart=on-failure
RestartSec=5
StandardOutput=append:$APP_LOG_FILE
StandardError=append:$APP_LOG_FILE
Environment=JAVA_OPTS="-Xms128m -Xmx256m"

[Install]
WantedBy=multi-user.target
EOF

chown root:root "$SYSTEMD_SERVICE_FILE"
chmod 644 "$SYSTEMD_SERVICE_FILE"
systemctl daemon-reload
systemctl enable "$SYSTEMD_SERVICE_NAME.service"

log_info "systemd service instalado/atualizado"
