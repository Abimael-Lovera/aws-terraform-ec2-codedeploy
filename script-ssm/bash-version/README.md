# Bash Version - AppSettings Extractor

Scripts em Bash/Shell para extrair arquivos `appsettings.json` de servidores Windows via SSM.

## 📁 Arquivos

- **`extract_appsettings_windows.sh`** - 🎯 **PRINCIPAL** - Script Bash que você executa
- **`extract_appsettings.ps1`** - 📚 **REFERÊNCIA** - Exemplo PowerShell (não usado diretamente)

> ❗ **IMPORTANTE:** Você usa apenas o `.sh` - ele envia comandos PowerShell automaticamente via SSM!

## 🚀 Uso (Apenas o script Bash)

```bash
# Tornar executável
chmod +x extract_appsettings_windows.sh

# Executar (o script faz tudo automaticamente)
./extract_appsettings_windows.sh meu-profile-aws
```

> 💡 **O script Bash se conecta na AWS e envia comandos PowerShell via SSM automaticamente!**

## 🤔 Por que existem dois arquivos?

### **`extract_appsettings_windows.sh`** (O que você usa)

- ✅ Roda no **seu computador** (Mac/Linux)
- ✅ Conecta na AWS via SSM
- ✅ Envia comandos PowerShell para os servidores Windows
- ✅ Baixa os arquivos para seu computador

### **`extract_appsettings.ps1`** (Apenas referência)

- 📚 Script PowerShell de **exemplo/referência**
- 📚 Mostra como buscar arquivos **localmente** no Windows
- 📚 **NÃO é executado diretamente** pelo script Bash

> 🎯 **RESUMO:** Use apenas o `.sh` - ele envia os comandos PowerShell automaticamente!

## ⚙️ Configurações

Edite as variáveis no início do script `extract_appsettings_windows.sh`:

```bash
AWS_PROFILE="${AWS_PROFILE:-default}"
SERVER_NAME_FILTER="SI2"
TARGET_PATH="D\\Sites\\Api"
LOCAL_BACKUP_DIR="./config_backups/$(date +%Y%m%d_%H%M%S)"
```

## 📋 Funcionalidades

✅ **Busca automática** de servidores Windows com filtro  
✅ **Verificação SSM** antes de acessar  
✅ **Logs coloridos** no terminal  
✅ **Estrutura organizada** de arquivos extraídos  
✅ **Metadados** de extração  
✅ **Tratamento de erros** básico

## 📂 Estrutura de Saída

```
config_backups_YYYYMMDD_HHMMSS/
├── SI2-WEB-01/
│   ├── appsettings.json
│   ├── appsettings.SI2-WEB-01.json
│   └── metadata.txt
└── SI2-API-02/
    ├── appsettings.json
    ├── appsettings.SI2-API-02.json
    └── metadata.txt
```

## 🔧 Requisitos

- **Bash** (macOS/Linux)
- **AWS CLI** instalado e configurado
- **Profile AWS** com permissões SSM e EC2
- **Servidores Windows** com SSM Agent ativo

## 🎯 Quando Usar

- ✅ Ambiente com Bash nativo
- ✅ Não quer instalar Python/dependências
- ✅ Processamento sequencial é suficiente
- ✅ Logs simples no terminal
