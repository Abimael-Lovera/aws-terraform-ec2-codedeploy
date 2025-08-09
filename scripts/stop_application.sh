#!/bin/bash -e
# Para a aplicação Spring Boot

PID_FILE=/var/run/app.pid

if [ -f "$PID_FILE" ]; then
  PID=$(cat $PID_FILE)
  if kill -0 $PID 2>/dev/null; then
    echo "[INFO] Parando aplicação (PID $PID)"
    kill $PID
    sleep 5
    if kill -0 $PID 2>/dev/null; then
      echo "[WARN] Forçando término"
      kill -9 $PID
    fi
  else
    echo "[INFO] Processo não está em execução"
  fi
  rm -f $PID_FILE
else
  echo "[INFO] PID file não encontrado"
fi
