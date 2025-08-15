# Python Version - AppSettings Extractor

Scripts em Python para extrair arquivos `appsettings.json` de servidores Windows via SSM.

## 📁 Arquivos

- **`extract_simple.py`** - Script super simples (RECOMENDADO)
- **`quick_extract.py`** - Script rápido
- **`extract_appsettings.py`** - Script completo (avançado)
- **`setup.sh`** - Setup automático do ambiente
- **`requirements.txt`** - Dependências Python

## ⚡ Setup Rápido

```bash
# 1. Setup automático
./setup.sh

# 2. Ativar ambiente
source venv-appsettings-extractor/bin/activate

# 3. Usar scripts (SIMPLES)
python extract_simple.py meu-profile
python quick_extract.py meu-profile
python extract_appsettings.py --profile meu-profile

# 4. Desativar quando terminar
deactivate
```

## 🚀 Uso

### Script Simplificado

```bash
python quick_extract.py
python quick_extract.py meu-profile-aws
```

### Script Completo

```bash
# Ajuda
python extract_appsettings.py --help

# Uso básico
python extract_appsettings.py --profile meu-profile

# Opções avançadas
python extract_appsettings.py \
  --profile meu-profile \
  --filter SI2 \
  --target "D:\Sites\Api" \
  --concurrent 5 \
  --verbose
```

## ⚡ Funcionalidades Avançadas

✅ **Processamento Concorrente** - Múltiplas instâncias simultaneamente  
✅ **Logging Avançado** - Console colorido + arquivo detalhado  
✅ **Tratamento Robusto** - Timeouts, retry, error handling  
✅ **Metadados JSON** - Informações estruturadas  
✅ **Relatórios Completos** - Estatísticas e taxa de sucesso  
✅ **Configuração Flexível** - Argumentos de linha de comando  
✅ **Threading Seguro** - Pool de threads configurável

## 📊 Exemplo de Execução

```
🚀 Iniciando extração de arquivos appsettings.json
Profile AWS: meu-profile
Filtro de servidor: SI2
Operações simultâneas: 3

[2025-08-15 14:30:22] [INFO] Encontradas 3 instâncias
[2025-08-15 14:30:25] [INFO] ✅ SSM ativo para SI2-WEB-01
[2025-08-15 14:30:28] [INFO] 📁 Extraindo arquivos de SI2-WEB-01...
[2025-08-15 14:30:30] [INFO] ✅ Extraído: appsettings.json
[2025-08-15 14:30:32] [INFO] ✅ Extraído: appsettings.SI2-WEB-01.json

📊 RELATÓRIO FINAL
Instâncias encontradas: 3
Instâncias com sucesso: 3
Total de arquivos extraídos: 6
🎯 Taxa de sucesso: 100.0%
🎉 Extração concluída com sucesso!
```

## 📂 Estrutura de Saída

```
config_backups_YYYYMMDD_HHMMSS/
├── SI2-WEB-01/
│   ├── appsettings.json
│   ├── appsettings.SI2-WEB-01.json
│   └── metadata.json  # 🆕 JSON estruturado
├── SI2-API-02/
│   └── ...
└── logs/
    └── extract_appsettings_YYYYMMDD_HHMMSS.log  # 🆕 Log detalhado
```

### Exemplo metadata.json

```json
{
  "instance_id": "i-1234567890abcdef0",
  "instance_name": "SI2-WEB-01",
  "hostname": "SI2-WEB-01",
  "private_ip": "10.0.1.100",
  "extraction_date": "2025-08-15T14:30:32.123456",
  "files_extracted": ["appsettings.json", "appsettings.SI2-WEB-01.json"],
  "files_count": 2,
  "ssm_status": "Online"
}
```

## 🎛️ Opções de Linha de Comando

```bash
python extract_appsettings.py [OPÇÕES]

  --profile, -p     Profile AWS (padrão: default)
  --filter, -f      Filtro para nome dos servidores (padrão: SI2)
  --target, -t      Caminho no Windows (padrão: D:\Sites\Api)
  --concurrent, -c  Operações simultâneas (padrão: 3)
  --verbose, -v     Logging detalhado (DEBUG)
  --help           Mostrar ajuda
```

## 📋 Requisitos

- **Python 3.7+**
- **boto3** (via requirements.txt)
- **AWS CLI** configurado
- **Profile AWS** com permissões SSM e EC2
- **Servidores Windows** com SSM Agent ativo

## 🎯 Quando Usar

- ✅ Múltiplas instâncias (processamento paralelo)
- ✅ Logs detalhados e organizados
- ✅ Relatórios e estatísticas completas
- ✅ Tratamento robusto de erros
- ✅ Flexibilidade de configuração
- ✅ Ambiente Python disponível

## 🔧 Solução de Problemas

### Timeout em comandos

```bash
# Reduzir concorrência
python extract_appsettings.py --concurrent 1

# Logs detalhados
python extract_appsettings.py --verbose
```

### Verificar logs

```bash
tail -f logs/extract_appsettings_*.log
```
