#!/bin/bash -e
# Inicia a aplicação Spring Boot

APP_JAR=$(ls /opt/app/app-*.jar | head -n1)
LOG_FILE=/var/log/app.log
PID_FILE=/var/run/app.pid

if [ -z "$APP_JAR" ]; then
  echo "[ERROR] JAR não encontrado em /opt/app" >&2
  exit 1
fi

if [ -f "$PID_FILE" ] && kill -0 $(cat $PID_FILE) 2>/dev/null; then
  echo "[INFO] Aplicação já em execução"
  exit 0
fi

echo "[INFO] Ajustando permissões"
chown appuser:appuser "$APP_JAR" || true

echo "[INFO] Iniciando aplicação: $APP_JAR como appuser"
sudo -u appuser nohup java -jar "$APP_JAR" > "$LOG_FILE" 2>&1 &
echo $! > $PID_FILE
chown appuser:appuser $PID_FILE || true

echo "[INFO] Aplicação iniciada (PID $(cat $PID_FILE))"
