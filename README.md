# Contador App com Terraform e CodeDeploy

Aplicação Spring Boot simples com dois endpoints:

- `/healthcheck` retorna status UP
- `/contador` incrementa e retorna contador em memória

Infraestrutura AWS (Free Tier) via Terraform:
- VPC + 2 Subnets públicas + IGW + Route Table compartilhada
- Security Group para SSH (22) e HTTP (8080) restritos por variável `allowed_cidr`
- EC2 Amazon Linux 2023 t2.micro (1..N via variável `instance_count` distribuídas entre as subnets)
- CodeDeploy (App + Deployment Group)

## Passos por Etapas

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

### 7. Build da Aplicação
```
cd ../app
mvn clean package
```
Gera `target/app-0.0.1-SNAPSHOT.jar`.

### 8. Criar Revision para CodeDeploy (ZIP)
```
zip -r deployment.zip appspec.yml target/app-0.0.1-SNAPSHOT.jar
```
(Adicionar scripts se necessário no mesmo zip em um diretório apropriado.)

### 9. Realizar Deployment
Use AWS CLI: `aws deploy create-deployment ...` (adicionar comandos conforme configuração de bucket / S3 ou GitHub).

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


