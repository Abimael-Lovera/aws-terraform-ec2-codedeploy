# Guia de Configuração: AWS CLI + Terraform + Deploy da Aplicação

Este guia descreve passo a passo como preparar seu ambiente local (macOS) para realizar o deploy da infraestrutura e da aplicação Spring Boot na AWS usando Terraform e CodeDeploy.

---
## 1. Pré-Requisitos Locais

1. macOS atualizado
2. Homebrew instalado (https://brew.sh/)
3. Conta AWS ativa (com usuário IAM ou acesso SSO)
4. Permissões mínimas IAM para: EC2, VPC, IAM Roles, CodeDeploy, S3, CloudWatch, SSM
5. Git instalado

### 1.1 Instalar Ferramentas
```bash
# AWS CLI v2
brew install awscli

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# (Opcional) jq para parse de JSON
brew install jq

# Maven (se não tiver)
brew install maven
```

Verificar versões:
```bash
aws --version
terraform version
mvn -v
java -version
```

---
## 2. Configuração de Credenciais AWS

Você pode usar (a) Usuário IAM com Access Keys, (b) SSO IAM Identity Center ou (c) Perfis já existentes.

### 2.1 Via Access Keys (Usuário IAM)
Crie um usuário com política gerenciada (ex: PowerUserAccess ou conjunto mínimo customizado). Gere Access Key + Secret.
```bash
aws configure --profile contador-dev
# AWS Access Key ID: <sua_access_key>
# AWS Secret Access Key: <sua_secret_key>
# Default region name: us-east-1
# Default output format: json
```
Verifique:
```bash
aws sts get-caller-identity --profile contador-dev
```

### 2.2 Via SSO (IAM Identity Center)
```bash
aws configure sso --profile contador-dev
# Preencher SSO start URL, região SSO, account ID, role name, region padrão, formato
aws sso login --profile contador-dev
```

### 2.3 Estrutura de Arquivos (~/.aws)
- credentials
- config

Exemplo mínimo:
```
[profile contador-dev]
region = us-east-1
output = json
```

Use sempre o profile nas chamadas (ou export AWS_PROFILE=contador-dev).

---
## 3. Permissões Mínimas (Política Referencial)
Para ambiente de testes, uma política agregada pode incluir:
- ec2:*
- iam:*
- codedeploy:*
- s3:*
- cloudwatch:*
- logs:*
- ssm:*
- autoscaling:Describe*
- elasticloadbalancing:Describe*

Em produção, restrinja por recurso. (Opcional: posso fornecer política mínima depois.)

---
## 4. Preparar Backend do Terraform (Opcional, Recomendado)
Crie bucket S3 e tabela DynamoDB para state lock.
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile contador-dev)
STATE_BUCKET="contador-tf-state-$AWS_ACCOUNT_ID"
aws s3 mb s3://$STATE_BUCKET --profile contador-dev
aws s3api put-bucket-versioning --bucket $STATE_BUCKET --versioning-configuration Status=Enabled --profile contador-dev
aws dynamodb create-table \
  --table-name contador-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --profile contador-dev
```
Atualize `terraform/providers.tf` (exemplo):
```hcl
terraform {
  backend "s3" {
    bucket         = "contador-tf-state-123456789012"
    key            = "global/state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "contador-tf-lock"
    encrypt        = true
  }
}
```
Depois execute:
```bash
cd terraform
terraform init -migrate-state
```

Se não quiser backend remoto, ignore esta etapa (state ficará local).

---
## 5. Configurar Variáveis Terraform
Arquivo `terraform/variables.tf` já possui defaults. Necessário informar `key_name` (nome da chave SSH previamente criada).

Criar chave (caso não exista):
```bash
aws ec2 create-key-pair --key-name contador-key \
  --query 'KeyMaterial' --output text --profile contador-dev > contador-key.pem
chmod 400 contador-key.pem
```

Opcional: restringir acesso HTTP a seu IP público:
```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
terraform apply -var="key_name=contador-key" -var="allowed_cidr=$MY_IP" ...
```

---
## 6. Fluxo de Deploy Infraestrutura por Etapas
```bash
export AWS_PROFILE=contador-dev
cd terraform
terraform init
terraform validate

# VPC
terraform apply -target=module.vpc -auto-approve \
  -var="key_name=contador-key"

# EC2
terraform apply -target=module.ec2 -auto-approve \
  -var="key_name=contador-key"

# CodeDeploy
terraform apply -target=module.codedeploy -auto-approve \
  -var="key_name=contador-key"

# Full (quando quiser tudo junto em futuras execuções)
terraform apply -auto-approve -var="key_name=contador-key"
```
Outputs:
```bash
terraform output
```

---
## 7. Build e Pacote da Aplicação
Verificar Maven/JDK:
```bash
java -version
mvn -version
```
Build:
```bash
cd app
mvn clean package
```
OU pacote completo revision:
```bash
cd ..
./scripts/package_revision.sh
```
Gera `deployment.zip` na raiz.

---
## 8. Enviar Revision para S3
Criar bucket de revisions (1x):
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REV_BUCKET="contador-app-revisions-$ACCOUNT_ID-us-east-1"
aws s3 mb s3://$REV_BUCKET
aws s3 cp deployment.zip s3://$REV_BUCKET/deployment.zip
```

---
## 9. Criar Deployment CodeDeploy
Identificar nomes (default):
- Application: `contador-app-dev-app`
- Deployment Group: `contador-app-dev-dg`

Criar deployment:
```bash
aws deploy create-deployment \
  --application-name contador-app-dev-app \
  --deployment-group-name contador-app-dev-dg \
  --s3-location bucket=$REV_BUCKET,key=deployment.zip,bundleType=zip \
  --query 'deploymentId'
```
Monitorar:
```bash
DEPLOY_ID=<deploymentId>
aws deploy get-deployment --deployment-id $DEPLOY_ID \
  --query 'deploymentInfo.status'
```

---
## 10. Testar Aplicação
Obter IP:
```bash
cd terraform
PUBLIC_IP=$(terraform output -raw instance_public_ip)
```
Testar:
```bash
curl http://$PUBLIC_IP:8080/healthcheck
curl http://$PUBLIC_IP:8080/contador
```

---
## 11. Logs e Troubleshooting
Na instância:
```bash
ssh -i contador-key.pem ec2-user@$PUBLIC_IP
sudo tail -f /var/log/app.log
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
```
Erros comuns:
- CodeDeploy timeout: verifique permissões de scripts (chmod +x) e agente instalado.
- 403 ao criar deployment: verifique perfil AWS_PROFILE / credenciais.
- Sem resposta HTTP: security group pode não permitir seu IP (ajuste allowed_cidr).

---
## 12. Limpeza de Recursos
```bash
cd terraform
terraform destroy -auto-approve -var="key_name=contador-key"
```
Remover bucket (esvaziar primeiro) e tabela DynamoDB se criou backend.

---
## 13. Próximos Aprimoramentos
- Adicionar ALB e Auto Scaling
- Observabilidade (CloudWatch Logs/metrics customizadas)
- Pipeline automatizado (CodePipeline ou GitHub Actions)
- Política IAM mínima segmentada por módulo

---
## 14. Checklist Rápido
- [ ] AWS CLI instalado
- [ ] Terraform instalado
- [ ] Credenciais configuradas (profile)
- [ ] Bucket state (opcional) criado
- [ ] Chave SSH criada
- [ ] terraform init/validate
- [ ] Apply VPC -> EC2 -> CodeDeploy
- [ ] Build jar / criar deployment.zip
- [ ] Upload S3
- [ ] create-deployment executado
- [ ] Teste dos endpoints OK

Pronto. Ajustes adicionais? Solicite e expandimos este guia.
