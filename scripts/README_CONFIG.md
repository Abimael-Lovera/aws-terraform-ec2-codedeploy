# Sistema de Configuração Global dos Scripts

Este documento explica como funciona o sistema de variáveis globais implementado para padronizar e facilitar a manutenção dos scripts de deployment.

## Arquivo Principal: `app_config.env`

O arquivo `app_config.env` contém todas as configurações centralizadas e funções utilitárias que são utilizadas por todos os scripts do deployment.

### Configurações Disponíveis

#### Aplicação

- `APP_NAME`: Nome da aplicação
- `APP_USER`/`APP_GROUP`: Usuário e grupo do sistema para a aplicação
- `APP_HOME`: Diretório de instalação da aplicação
- `APP_JAR_PATTERN`: Padrão para encontrar o arquivo JAR

#### Sistema

- `JAVA_VERSION`: Versão do Java a ser instalada
- `SYSTEMD_SERVICE_NAME`: Nome do serviço systemd

#### Rede

- `APP_HOST`/`APP_PORT`: Configurações de host e porta
- `HEALTH_ENDPOINT`: Endpoint para verificação de saúde
- `HEALTH_CHECK_URL`: URL completa para health check

#### Logs e PID

- `APP_LOG_FILE`: Arquivo de log da aplicação
- `INSTALL_LOG_FILE`: Log de instalação
- `PID_FILE`: Arquivo de PID da aplicação

#### Validação

- `HEALTH_CHECK_RETRIES`: Número de tentativas para validação
- `HEALTH_CHECK_SLEEP`: Intervalo entre tentativas

### Funções Utilitárias

#### Logging Padronizado

```bash
log_info "Mensagem informativa"
log_warn "Mensagem de aviso"
log_error "Mensagem de erro"
```

#### Gerenciamento de Aplicação

```bash
find_app_jar          # Encontra o JAR da aplicação
is_app_running        # Verifica se a aplicação está rodando
```

#### Setup do Sistema

```bash
ensure_app_user       # Cria o usuário se não existir
ensure_directories    # Cria diretórios necessários
ensure_java          # Instala Java se necessário
```

## Como Usar nos Scripts

Todos os scripts agora seguem este padrão:

```bash
#!/bin/bash -e
# Descrição do script

# Carrega configurações globais
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/app_config.env"

# Resto do código usando as variáveis e funções
```

## Scripts Atualizados

### `install_dependencies.sh`

- Usa `ensure_java()`, `ensure_app_user()`, `ensure_directories()`
- Log padronizado com `log_info()`
- Configurações centralizadas

### `start_application.sh`

- Usa `find_app_jar()` e `is_app_running()`
- Variáveis de usuário, diretórios e arquivos centralizadas
- Logging padronizado

### `stop_application.sh`

- Usa variáveis de PID centralizadas
- Logging padronizado

### `validate_service.sh`

- Usa configurações de URL e validação centralizadas
- Logging padronizado

### `install_systemd_service.sh`

- Usa configurações de systemd centralizadas
- Template do serviço com variáveis

## Vantagens do Sistema

### 1. **Centralização**

- Todas as configurações em um local
- Fácil manutenção e alteração
- Reduz duplicação de código

### 2. **Padronização**

- Logging consistente com timestamp
- Funções reutilizáveis
- Nomenclatura padronizada

### 3. **Flexibilidade**

- Fácil customização por ambiente
- Configurações podem ser sobrescritas
- Extensível para novas funcionalidades

### 4. **Manutenibilidade**

- Mudanças em um local refletem em todos os scripts
- Menos prone a erros
- Código mais limpo e legível

## Teste das Configurações

Execute o script de teste para validar todas as configurações:

```bash
./scripts/test_config.sh
```

Este script mostra:

- Todas as variáveis configuradas
- Testa as funções utilitárias
- Verifica o estado atual do sistema

## Customização

Para customizar as configurações para seu ambiente:

1. Edite o arquivo `scripts/app_config.env`
2. Modifique as variáveis conforme necessário
3. Execute o teste para validar as mudanças
4. Os scripts automaticamente usarão as novas configurações

## Exemplo de Customização

```bash
# Para mudar a porta da aplicação
export APP_PORT="9090"

# Para usar um diretório diferente
export APP_HOME="/home/app"

# Para aumentar tentativas de validação
export HEALTH_CHECK_RETRIES=30
```

Todas essas mudanças serão aplicadas automaticamente em todos os scripts sem necessidade de edição individual.
