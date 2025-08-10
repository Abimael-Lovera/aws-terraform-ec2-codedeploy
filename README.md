# Contador App com Terraform e CodeDeploy

Aplicação Spring Boot simples com dois endpoints:

- `/healthcheck` retorna status UP
- `/contador` incrementa e retorna contador em memória

Infraestrutura AWS (Free Tier) via Terraform:

- VPC + 2 Subnets públicas + IGW + Route Table compartilhada
- Security Group para SSH (22) e HTTP (8080) restritos por variável `allowed_cidr`
- EC2 Amazon Linux 2023 t2.micro (1..N via variável `instance_count` distribuídas entre as subnets)
- CodeDeploy (App + Deployment Group)

## Como usar

### 0. Verificação Pré-Deploy

```bash
# Execute a verificação completa antes de iniciar
./scripts/pre_deploy_check.sh
```

Este script verifica automaticamente:

- ✅ Dependências do sistema (AWS CLI, Terraform, Maven, Java, jq)
- ✅ Estrutura do projeto e arquivos necessários
- ✅ Configuração e sintaxe do Terraform
- ✅ Chave SSH e permissões
- ✅ Scripts de deploy e automação
- ✅ Compilação da aplicação Java
- ✅ Configuração AWS

### 1. Configurar AWS CLI e Terraform

Siga as instruções em [docs/SETUP_AWS_CLI_TERRAFORM.md](docs/SETUP_AWS_CLI_TERRAFORM.md).

### 2. Configurar variáveis do Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edite o arquivo terraform.tfvars com suas configurações
```

### 3. Provisionar infraestrutura

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Passos por Etapas (Alternativo)

### 1. Preparar Variáveis Sensíveis

Crie/defina a chave SSH previamente na AWS e informe via variável `key_name`.
Defina também o profile AWS que deseja usar (já configurado via `aws configure --profile <nome>`):

```
export AWS_PROFILE=meu-profile
export AWS_REGION=us-east-1
```

### 2. Inicializar Terraform (usando profile definido)

```
cd terraform
terraform init
terraform fmt -recursive
terraform validate
```

### 3. Aplicar Somente a VPC

Utilizando o profile através da variável de ambiente (não é preciso alterar o provider):

```
terraform apply -target=module.vpc -auto-approve \
	-var="key_name=MINHA_CHAVE"
```

Cria: VPC, 2 subnets públicas (variável `public_subnet_count`), IGW, route table e associações.

### 4. Ver Subnets

```
terraform output public_subnet_ids
```

### 5. Aplicar EC2 (definindo quantidade e distribuição entre subnets)

```
terraform apply -target=module.ec2 -auto-approve \
	-var="key_name=MINHA_CHAVE" \
	-var="subnet_index=0" \
	-var="instance_count=2"
```

Cria 2 instâncias (index 0 e 1) distribuídas circularmente pelas subnets públicas.

### 6. Aplicar CodeDeploy

```
terraform apply -target=module.codedeploy -auto-approve \
	-var="key_name=MINHA_CHAVE"
```

## Deploy Automatizado

### Scripts de Automação

Este projeto inclui scripts automatizados para facilitar o deploy e validação:

#### 1. Deploy Completo Automatizado

```bash
# Processo completo: build, deploy e validação
./scripts/deploy_and_validate.sh
```

O script executa automaticamente:

- Build da aplicação Spring Boot com Maven
- Criação da revisão para CodeDeploy
- Deploy via AWS CodeDeploy com monitoramento
- Validação dos endpoints após deploy

#### 2. Opções Específicas

```bash
# Apenas build da aplicação
./scripts/deploy_and_validate.sh --build-only

# Apenas deploy (assume build já feito)
./scripts/deploy_and_validate.sh --deploy-only

# Apenas validação pós-deploy
./scripts/deploy_and_validate.sh --validate-only
```

#### 3. Validação de Instâncias

```bash
# Validação única de todas as instâncias
./scripts/validate_instances.sh
```

Este script automatiza todas as verificações manuais:

- Conectividade SSH
- Espaço em disco disponível
- Instalação do Java 17
- Status do CodeDeploy Agent
- Usuário appuser e diretórios
- Status da aplicação (se deployada)
- Recursos do sistema

#### 4. Monitoramento de Saúde

```bash
# Status atual de todas as instâncias
./scripts/health_monitor.sh status

# Monitoramento contínuo (padrão: 30s)
./scripts/health_monitor.sh monitor

# Monitoramento personalizado (60s)
./scripts/health_monitor.sh monitor 60

# Teste de carga simples
./scripts/health_monitor.sh load-test 20 /contador
```

### Processo Manual (Alternativo)

Se preferir executar manualmente:

### 1. Build da Aplicação

```bash
cd app
mvn clean package
```

### 2. Criar Revision para CodeDeploy

```bash
cd ../scripts
./package_revision.sh
```

### 3. Deploy via AWS CLI

Use os outputs do Terraform para obter os nomes dos recursos e execute o deploy via AWS CLI.

## Security Group

Regra atual (arquivo Terraform módulo EC2):

- Ingress 22/tcp (SSH) de `allowed_cidr` (default 0.0.0.0/0) — recomenda-se restringir ao seu IP.
- Ingress 8080/tcp (aplicação) de `allowed_cidr`.
- Egress liberado 0.0.0.0/0.

Exemplo de chamada com IP restrito:

```
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
terraform apply -target=module.ec2 -var="key_name=MINHA_CHAVE" -var="allowed_cidr=$MY_IP"
```

Usando outro profile temporariamente sem export fixo:

```
AWS_PROFILE=outro-profile terraform plan -var="key_name=MINHA_CHAVE"
```

Melhorias sugeridas (não implementadas ainda):

- Separar SG de SSH e SG de aplicação.
- Criar variável `http_port`.
- Restringir egress apenas às portas necessárias (80/443, resolver DNS 53 UDP/TCP).
- Adicionar SG para futuro ALB.

## Próximos Aprimoramentos

- Adicionar configuração CloudWatch Logs e export de métricas.
- Backend remoto (S3 + DynamoDB) para state (ver docs/SETUP_AWS_CLI_TERRAFORM.md).
- Política IAM mínima personalizada em vez de políticas gerenciadas amplas.
- Adicionar health check /actuator/health e readiness/liveness probes para uso futuro com Load Balancer ou Kubernetes.
- Pipeline CI/CD (CodePipeline ou GitHub Actions com artifact S3).
- Adicionar opção de segunda instância e (opcional) ALB para balanceamento.

## Systemd e Validação

Durante o deploy:

- Hook AfterInstall cria/atualiza unidade systemd `contador-app.service`.
- Hook ApplicationStart chama script de start (fallback manual) mas systemd já pode gerenciar.
- Hook ValidateService verifica `/healthcheck` (scripts/validate_service.sh).

Gerenciar serviço manualmente (SSH):

```
sudo systemctl status contador-app
sudo systemctl restart contador-app
sudo journalctl -u contador-app -f
```

## Script Auxiliar Terraform com Profile

Para usar sempre o profile `alm-yahoo-account` sem export manual:

```
./scripts/terraform_apply_with_profile.sh plan
./scripts/terraform_apply_with_profile.sh apply -var="key_name=MINHA_CHAVE" -auto-approve
./scripts/terraform_apply_with_profile.sh output
```
