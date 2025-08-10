# Scripts de Automação

Este diretório contém scripts para automatizar o processo de deploy, validação e monitoramento da aplicação.

## Scripts Disponíveis

### 0. `pre_deploy_check.sh`

**Descrição**: Script de verificação pré-deploy para validar se tudo está pronto.

**Funcionalidades**:

- Verificação de dependências do sistema
- Validação da estrutura do projeto
- Verificação da configuração Terraform
- Validação da chave SSH
- Teste de compilação da aplicação
- Verificação da configuração AWS
- Relatório completo com status

**Uso**:

```bash
# Verificação completa
./scripts/pre_deploy_check.sh

# Modo verboso (debug)
./scripts/pre_deploy_check.sh --verbose
```

### 1. `deploy_and_validate.sh`

**Descrição**: Script principal para deploy completo automatizado.

**Funcionalidades**:

- Build da aplicação Spring Boot com Maven
- Execução de testes automatizados
- Criação da revisão para CodeDeploy
- Upload para S3 e deploy via AWS CodeDeploy
- Monitoramento do progresso do deploy
- Validação dos endpoints após deploy

**Uso**:

```bash
# Processo completo
./scripts/deploy_and_validate.sh

# Apenas build
./scripts/deploy_and_validate.sh --build-only

# Apenas deploy
./scripts/deploy_and_validate.sh --deploy-only

# Apenas validação
./scripts/deploy_and_validate.sh --validate-only
```

**Pré-requisitos**:

- AWS CLI configurado
- Terraform com estado válido
- Maven instalado
- jq instalado
- Chave SSH no diretório raiz

### 2. `validate_instances.sh`

**Descrição**: Automatiza todas as verificações manuais das instâncias EC2.

**Funcionalidades**:

- Teste de conectividade SSH
- Verificação de espaço em disco
- Validação da instalação do Java 17
- Status do CodeDeploy Agent
- Verificação do usuário appuser
- Status da aplicação
- Verificação de recursos do sistema

**Uso**:

```bash
./scripts/validate_instances.sh
```

**Saída de exemplo**:

```
[2024-01-15 10:30:00] === Validando instância Instance-1 (18.234.35.219) ===
✓ SSH conectividade OK
✓ Espaço em disco adequado: 15% usado
✓ Java 17 instalado corretamente
✓ CodeDeploy Agent está ativo
✓ Usuário appuser existe
✓ Permissões do diretório /opt/app estão corretas
ℹ Aplicação contador-app ainda não foi deployada (normal)
```

### 3. `health_monitor.sh`

**Descrição**: Monitoramento de saúde da aplicação com múltiplos modos de operação.

**Funcionalidades**:

- Status único de todas as instâncias
- Monitoramento contínuo com intervalo configurável
- Teste de carga simples
- Verificação de endpoints
- Monitoramento de recursos

**Uso**:

```bash
# Status atual
./scripts/health_monitor.sh status

# Monitoramento contínuo (30s)
./scripts/health_monitor.sh monitor

# Monitoramento personalizado (60s)
./scripts/health_monitor.sh monitor 60

# Teste de carga (50 requests no /contador)
./scripts/health_monitor.sh load-test 50 /contador
```

### 4. Scripts de Deploy (hooks do CodeDeploy)

#### `install_dependencies.sh`

- Hook: BeforeInstall
- Instala dependências do sistema
- Cria usuário appuser
- Configura diretórios

#### `stop_application.sh`

- Hook: ApplicationStop
- Para a aplicação se estiver rodando

#### `start_application.sh`

- Hook: ApplicationStart
- Inicia a aplicação Spring Boot

#### `install_systemd_service.sh`

- Hook: AfterInstall
- Configura serviço systemd
- Define permissões

#### `validate_service.sh`

- Hook: ValidateService
- Valida se aplicação está respondendo
- Testa endpoints críticos

## Fluxo de Trabalho Recomendado

### Deploy Inicial

```bash
# 1. Provisionar infraestrutura
cd terraform
terraform apply

# 2. Deploy completo da aplicação
cd ..
./scripts/deploy_and_validate.sh

# 3. Verificar saúde
./scripts/health_monitor.sh status
```

### Deploy de Atualização

```bash
# Após mudanças no código
./scripts/deploy_and_validate.sh
```

### Monitoramento Regular

```bash
# Para troubleshooting
./scripts/health_monitor.sh monitor

# Para testes de performance
./scripts/health_monitor.sh load-test 100
```

### Validação Rápida

```bash
# Verificação rápida das instâncias
./scripts/validate_instances.sh
```

## Dependências

Todos os scripts requerem:

- **bash**: Shell Unix
- **jq**: Processamento JSON
- **terraform**: Para obter outputs da infraestrutura
- **aws cli**: Para operações AWS
- **maven**: Para build da aplicação Java
- **ssh**: Para acesso às instâncias
- **curl**: Para testes de endpoint (via SSH)

### Instalação no macOS

```bash
brew install jq terraform awscli maven
```

## Configuração

### Chave SSH

A chave SSH deve estar no diretório raiz do projeto com o nome `contador-app-key-ssh.pem`:

```bash
# Verificar se existe
ls contador-app-key-ssh.pem

# Ajustar permissões se necessário
chmod 600 contador-app-key-ssh.pem
```

### AWS CLI

Configure o AWS CLI com perfil adequado:

```bash
aws configure --profile meu-profile
export AWS_PROFILE=meu-profile
```

### Terraform

Certifique-se de que o Terraform está inicializado e com estado válido:

```bash
cd terraform
terraform init
terraform validate
```

## Troubleshooting

### Erro de SSH

```
[ERROR] Falha na conectividade SSH para X.X.X.X
```

**Solução**: Verificar Security Group e chave SSH.

### Erro de Dependências

```
[ERROR] Dependências não encontradas: jq maven
```

**Solução**: Instalar dependências faltantes.

### Timeout no Deploy

```
[ERROR] Timeout no deployment após 30 tentativas
```

**Solução**: Verificar logs do CodeDeploy Agent nas instâncias.

### Aplicação não responde

```
❌ Endpoint /healthcheck falhou
```

**Solução**: Verificar logs da aplicação e status do serviço systemd.

## Logs e Diagnóstico

### Logs da Aplicação

```bash
# Via SSH na instância
sudo journalctl -u contador-app -f
sudo tail -f /var/log/app.log
```

### Logs do CodeDeploy

```bash
# Via SSH na instância
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
```

### Status dos Serviços

```bash
# Via SSH na instância
sudo systemctl status contador-app
sudo systemctl status codedeploy-agent
```

## Extensibilidade

Os scripts são modulares e podem ser facilmente estendidos:

1. **Adicionar novas validações**: Modificar `validate_instances.sh`
2. **Personalizar monitoramento**: Estender `health_monitor.sh`
3. **Hooks adicionais**: Criar novos scripts na pasta e referenciar no `appspec.yml`
4. **Métricas customizadas**: Integrar com CloudWatch nos scripts de monitoramento

## Segurança

- Scripts usam conexões SSH com timeout configurado
- Chaves SSH com permissões restritas (600)
- Comandos executados com privilégios mínimos necessários
- Logs não expõem informações sensíveis
