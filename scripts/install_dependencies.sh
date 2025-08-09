#!/bin/bash -e
# Instala dependências necessárias para rodar a aplicação

LOG_FILE=/var/log/app_install.log
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "[INFO] Iniciando instalação de dependências"

if ! command -v java >/dev/null 2>&1; then
  echo "[INFO] Instalando Corretto 17"
  dnf install -y java-17-amazon-corretto-headless
fi

echo "[INFO] Criando usuário de aplicação se não existir"
id -u appuser 2>/dev/null || useradd -r -s /sbin/nologin appuser
mkdir -p /opt/app
chown appuser:appuser /opt/app

echo "[INFO] Instalação concluída"
