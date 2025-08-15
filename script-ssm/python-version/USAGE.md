# Como usar - AppSettings Extractor Python

## ## 📝 Exemplo Completo:

````bash
# 1. Ir para pasta (uma vez)
cd script-ssm/python-version

# 2. Setup inicial (só na primeira vez)
./setup.sh

# 3. Ativar ambiente (sempre que usar)
source venv-appsettings-extractor/bin/activate

# 4. Executar script (MAIS SIMPLES)
python extract_simple.py alm-yahoo-account

# 5. Desativar quando terminar
deactivate
```o (Passo a Passo)

### 1️⃣ PRIMEIRA VEZ (Setup inicial):

```bash
# Navegar para a pasta
cd script-ssm/python-version

# Executar setup (cria ambiente e instala dependências)
./setup.sh
````

### 2️⃣ SEMPRE QUE FOR USAR (Ativar ambiente):

```bash
# Ativar o ambiente virtual Python
source venv-appsettings-extractor/bin/activate

# Agora você verá (venv-appsettings-extractor) no prompt
```

### 3️⃣ EXECUTAR O SCRIPT:

```bash
# OPÇÃO A: Script super simples (RECOMENDADO)
python extract_simple.py meu-profile-aws

# OPÇÃO B: Script rápido
python quick_extract.py meu-profile-aws

# OPÇÃO C: Script completo (avançado)
python extract_appsettings.py --profile meu-profile-aws
```

python extract_appsettings.py --profile meu-profile-aws --verbose

````

### 4️⃣ FINALIZAR (Desativar ambiente):

```bash
# Desativar o ambiente virtual
deactivate

# O prompt volta ao normal
````

## � Exemplo Completo:

```bash
# 1. Ir para pasta (uma vez)
cd script-ssm/python-version

# 2. Setup inicial (só na primeira vez)
./setup.sh

# 3. Ativar ambiente (sempre que usar)
source venv-appsettings-extractor/bin/activate

# 4. Executar script
python quick_extract.py alm-yahoo-account

# 5. Desativar quando terminar
deactivate
```

## 📁 O que acontece:

- **Setup**: Cria pasta `venv-appsettings-extractor/` e instala boto3
- **Ativar**: Muda o Python para usar as dependências instaladas
- **Executar**: Roda o script que extrai os arquivos dos servidores Windows
- **Desativar**: Volta ao Python do sistema

## 🎯 Resumo:

1. Setup (só uma vez)
2. Ativar → Usar → Desativar (sempre que precisar)
