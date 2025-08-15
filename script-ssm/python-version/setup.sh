#!/bin/bash

# Setup simples do ambiente Python para os scripts
# Uso: ./setup.sh

echo "🐍 Configurando ambiente Python..."

# Criar venv se não existir
if [ ! -d "venv-appsettings-extractor" ]; then
    echo "Criando ambiente virtual..."
    python3 -m venv venv-appsettings-extractor
fi

# Ativar e instalar dependências
echo "Instalando dependências..."
source venv-appsettings-extractor/bin/activate
pip install boto3 > /dev/null 2>&1

echo "✅ Pronto!"
echo
echo "Para usar:"
echo "  source venv-appsettings-extractor/bin/activate"
echo "  python extract_appsettings.py --profile alm-yahoo-account"
echo "  deactivate"
