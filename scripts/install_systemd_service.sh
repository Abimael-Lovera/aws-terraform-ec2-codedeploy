#!/bin/bash -e
# Cria/atualiza unidade systemd para a aplicação
SERVICE_FILE=/etc/systemd/system/contador-app.service
APP_DIR=/opt/app
JAR=$(ls $APP_DIR/app-*.jar 2>/dev/null | head -n1)
USER=appuser
LOG_FILE=/var/log/app.log

if [ -z "$JAR" ]; then
  echo "[ERROR] JAR não encontrado em $APP_DIR" >&2
  exit 1
fi

cat > $SERVICE_FILE <<EOF
[Unit]
Description=Contador Spring Boot App
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/java -jar $JAR
Restart=on-failure
RestartSec=5
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
Environment=JAVA_OPTS="-Xms128m -Xmx256m"

[Install]
WantedBy=multi-user.target
EOF

chown root:root $SERVICE_FILE
chmod 644 $SERVICE_FILE
systemctl daemon-reload
systemctl enable contador-app.service

echo "[INFO] systemd service instalado/atualizado"
