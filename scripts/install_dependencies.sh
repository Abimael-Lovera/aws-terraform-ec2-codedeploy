#!/bin/bash -e
# Instala dependências necessárias para rodar a aplicação

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

# Redireciona output para log
exec > >(tee -a ${INSTALL_LOG_FILE}) 2>&1

log_info "Iniciando instalação de dependências"

# Instala Java se necessário
ensure_java

# Cria usuário da aplicação
ensure_app_user

# Cria diretórios necessários
ensure_directories

log_info "Instalação concluída"
