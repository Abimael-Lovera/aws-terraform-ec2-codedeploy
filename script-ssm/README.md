# Script SSM - AppSettings Extractor

Conjunto completo de scripts para extrair arquivos `appsettings.json` de servidores Windows na AWS via Systems Manager (SSM).

## 📁 Estrutura

```
script-ssm/
├── bash-version/                    # 🔧 Scripts Bash/Shell
│   ├── extract_appsettings_windows.sh
│   ├── extract_appsettings.ps1
│   └── README.md
├── python-version/                  # 🐍 Scripts Python (RECOMENDADO)
│   ├── extract_appsettings.py
│   ├── quick_extract.py
│   ├── requirements.txt
│   └── README.md
└── README.md                        # Esta documentação
```

## 🎯 Qual Versão Escolher?

### 🐍 Python Version (Recomendada)

**Melhor para: Múltiplas instâncias, logs detalhados, processamento eficiente**

```bash
cd python-version
pip install -r requirements.txt
python extract_appsettings.py --profile meu-profile
```

**Vantagens:**

- ⚡ **Processamento paralelo** (múltiplas instâncias simultaneamente)
- 📊 **Relatórios detalhados** com estatísticas
- 🎨 **Logs coloridos** + arquivo de log estruturado
- 🛡️ **Tratamento robusto** de erros e timeouts
- ⚙️ **Configuração flexível** via argumentos
- 📋 **Metadados JSON** estruturados

### 🔧 Bash Version

**Melhor para: Ambiente minimalista, sem dependências Python**

```bash
cd bash-version
chmod +x extract_appsettings_windows.sh
./extract_appsettings_windows.sh meu-profile
```

**Vantagens:**

- 🚀 **Sem dependências** (apenas Bash + AWS CLI)
- 💻 **Nativo** em sistemas Unix/Linux/macOS
- 🎯 **Simples** e direto
- 📝 **Logs básicos** coloridos

## 📊 Comparação Rápida

| Funcionalidade    | Python     | Bash       |
| ----------------- | ---------- | ---------- |
| **Performance**   | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     |
| **Logging**       | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐   |
| **Configuração**  | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     |
| **Relatórios**    | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     |
| **Simplicidade**  | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐ |
| **Portabilidade** | ⭐⭐⭐⭐   | ⭐⭐⭐⭐⭐ |

## 🚀 Uso Rápido

### Cenário 1: Primeiro Uso

```bash
# 1. Clone ou acesse o projeto
cd script-ssm

# 2. Escolha a versão Python (recomendada)
cd python-version
pip install -r requirements.txt

# 3. Execute
python quick_extract.py meu-profile-aws
```

### Cenário 2: Uso Avançado (Python)

```bash
cd python-version

# Múltiplas configurações
python extract_appsettings.py \
  --profile producao \
  --filter "PROD-SI2" \
  --target "D:\Apps\Config" \
  --concurrent 10 \
  --verbose
```

### Cenário 3: Ambiente Simples (Bash)

```bash
cd bash-version
chmod +x extract_appsettings_windows.sh
AWS_PROFILE=meu-profile ./extract_appsettings_windows.sh
```

## 🎯 Casos de Uso

### 📊 Multiple Servers (Python Recomendada)

- Quando você tem **muitos servidores** para processar
- Precisa de **performance** e processamento paralelo
- Quer **logs detalhados** e relatórios

### 🔧 Single/Few Servers (Bash OK)

- Quando você tem **poucos servidores**
- Prefere **simplicidade** sem dependências
- Ambiente **minimalista**

### 🏢 Ambiente Corporativo (Python)

- Precisa de **auditoria** e logs estruturados
- Requer **relatórios** para compliance
- **Múltiplos ambientes** e configurações

### 🛠️ Troubleshooting (Bash)

- **Teste rápido** de conectividade
- **Debug** de um servidor específico
- **Prototipagem** de soluções

## 📋 Pré-requisitos Comum

- **AWS CLI** instalado e configurado
- **Profile AWS** com permissões:
  - `ec2:DescribeInstances`
  - `ssm:DescribeInstanceInformation`
  - `ssm:SendCommand`
  - `ssm:GetCommandInvocation`
- **Servidores Windows** com:
  - SSM Agent instalado e ativo
  - Nome contendo o filtro especificado (ex: "SI2")
  - Diretório target existente (ex: `D:\Sites\Api`)

## 🔧 Configuração Rápida AWS

```bash
# Configurar profile AWS
aws configure --profile meu-profile

# Testar conectividade
aws sts get-caller-identity --profile meu-profile

# Listar instâncias Windows
aws ec2 describe-instances \
  --profile meu-profile \
  --filters "Name=platform,Values=windows" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]'
```

## 📂 Estrutura de Saída (Ambas as Versões)

```
config_backups_YYYYMMDD_HHMMSS/          # Diretório principal
├── SI2-WEB-01/                          # Por servidor
│   ├── appsettings.json                 # Arquivo principal
│   ├── appsettings.SI2-WEB-01.json      # Arquivo específico do hostname
│   └── metadata.{txt|json}              # Metadados (formato varia)
├── SI2-API-02/
│   └── ...
└── logs/                                # 🐍 Só na versão Python
    └── extract_appsettings_*.log
```

## 🎨 Exemplo de Saída

### Python Version

```
🚀 Iniciando extração de arquivos appsettings.json
Profile AWS: producao
Filtro de servidor: SI2
Operações simultâneas: 5

[2025-08-15 14:30:22] [INFO] Encontradas 10 instâncias
[2025-08-15 14:30:25] [INFO] 🔄 Processando: SI2-WEB-01 (i-1234567890abcdef0)
[2025-08-15 14:30:25] [INFO] ✅ SSM ativo para SI2-WEB-01
[2025-08-15 14:30:28] [INFO] 📁 Extraindo arquivos de SI2-WEB-01...
[2025-08-15 14:30:30] [INFO] ✅ Extraído: appsettings.json
[2025-08-15 14:30:32] [INFO] ✅ Extraído: appsettings.SI2-WEB-01.json

📊 RELATÓRIO FINAL
==================================================
Instâncias encontradas: 10
Instâncias processadas: 10
Instâncias com sucesso: 9
Total de arquivos extraídos: 18
🎯 Taxa de sucesso: 90.0%
🎉 Extração concluída com sucesso!
```

### Bash Version

```
=== Extrator de AppSettings.json - Servidores Windows ===
Profile AWS: producao
Filtro: SI2
Diretório de saída: ./config_backups_20250815_143022

Buscando instâncias Windows com 'SI2' no nome...
Instâncias encontradas:
i-1234567890abcdef0    SI2-WEB-01
i-0987654321fedcba0    SI2-API-02

Processando: SI2-WEB-01 (i-1234567890abcdef0)
  SSM ativo, extraindo arquivos...
  Extraído: appsettings.json
  Extraído: appsettings.SI2-WEB-01.json
  Concluído: SI2-WEB-01

=== EXTRAÇÃO FINALIZADA ===
Arquivos salvos em: ./config_backups_20250815_143022
```

## 🔍 Links Úteis

- **[Python Version README](python-version/README.md)** - Documentação detalhada Python
- **[Bash Version README](bash-version/README.md)** - Documentação detalhada Bash
- **[AWS SSM Documentation](https://docs.aws.amazon.com/systems-manager/)** - Documentação oficial AWS SSM

## 💡 Dicas

1. **Primeiro uso**: Comece com a versão Python e `quick_extract.py`
2. **Performance**: Use `--concurrent` maior para mais servidores
3. **Debug**: Use `--verbose` na versão Python para logs detalhados
4. **Segurança**: Mantenha os arquivos extraídos em local seguro
5. **Limpeza**: Remova backups antigos regularmente
