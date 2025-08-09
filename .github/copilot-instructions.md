# Instruções para o GitHub Copilot

## Objetivo do Projeto

Criar uma aplicação Java com Spring Boot que disponibiliza dois endpoints:

- `/healthcheck`: Verifica se a aplicação está rodando.
- `/contador`: Conta e retorna o número total de chamadas feitas à API, armazenando essa contagem em memória.

Além disso, a infraestrutura será provisionada utilizando Terraform, incluindo:

- VPC com duas subnets públicas (configurável via `public_subnet_count`).
- Instância(s) EC2 configuráveis (variável `instance_count`) em múltiplas subnets com chave SSH.
- Security Group controlando portas SSH/APP com variáveis `allowed_cidr`, `allowed_cidr_ssh`, `allowed_cidr_http`.
- Automação de deploy da aplicação utilizando AWS CodeDeploy.

Todos os recursos devem ser configurados para operar dentro do Free Tier da AWS, visando baixo custo.

## Estrutura do Projeto

```
aws-terraform-ec2-codedeploy/
├── app/                              # Aplicação Spring Boot
│   ├── src/
│   │   └── main/
│   │       ├── java/com/example/app/ # Código fonte Java
│   │       └── resources/            # Recursos da aplicação
│   └── pom.xml                       # Dependências Maven
├── terraform/                        # Código Terraform
│   ├── main.tf                       # Configuração principal
│   ├── variables.tf                  # Definição de variáveis
│   ├── outputs.tf                    # Outputs do Terraform
│   ├── providers.tf                  # Configuração de providers
│   └── modules/                      # Módulos Terraform
│       ├── vpc/                      # Módulo de VPC
│       ├── ec2/                      # Módulo de EC2
│       └── codedeploy/              # Módulo de CodeDeploy
└── scripts/                          # Scripts de automação
    ├── install_dependencies.sh       # Instalação de dependências
    └── start_application.sh          # Script para iniciar a aplicação
```

## Objetivo do Projeto

Criar uma aplicação Java com Spring Boot que disponibiliza dois endpoints:

- `/healthcheck`: Verifica se a aplicação está rodando.
- `/contador`: Conta e retorna o número total de chamadas feitas à API, armazenando essa contagem em memória.

Além disso, a infraestrutura será provisionada utilizando Terraform, incluindo:

- VPC com duas subnet pública.
- Instâncias EC2 estáticas configuradas com chave SSH.
- Automação de deploy da aplicação utilizando AWS CodeDeploy.

Todos os recursos devem ser configurados para operar dentro do Free Tier da AWS, visando baixo custo.

## Diretrizes de Codificação

- **Linguagem**: Java 17+.
- **Framework**: Spring Boot 3.x.
- **Gerenciamento de Dependências**: Maven.
- **Estilo de Código**: Seguir as melhores práticas de codificação Java, com ênfase em clareza e simplicidade.

## Infraestrutura como Código (IaC)

- **Ferramenta**: Terraform.
- **Objetivo**: Provisionar recursos na AWS dentro do Free Tier.
- **Componentes**:
  - VPC com 2 subnets públicas (padrão) e Internet Gateway + Route Table compartilhada.
  - Security Group único inicial permitindo 22 e 8080 do CIDR configurado (`allowed_cidr`).
  - Variável `subnet_index` para selecionar em qual subnet lançar a instância EC2.
  - Instâncias EC2 Amazon Linux 2023 t2.micro com Java 17 (Corretto) via user_data (inclui instalação do agente CodeDeploy).
  - IAM Role/Instance Profile com políticas para CodeDeploy, CloudWatch e SSM.
  - CodeDeploy Application + Deployment Group filtrando por tag Name.

## Automação de Deploy

- **Ferramenta**: AWS CodeDeploy.
- **Objetivo**: Automatizar o deploy da aplicação Spring Boot.
- **Configuração**:
  - Scripts de instalação para configurar o Java.
  - Execução do arquivo JAR da aplicação.
  - Criação automática de unidade systemd e validação pós-deploy via hook ValidateService.

## Considerações Finais

- **Custos**: Todos os recursos dentro do Free Tier (t2.micro, 1 instância, sem ALB inicialmente).
- **Segurança**: Restringir `allowed_cidr` ao IP do desenvolvedor. Separar futuramente SG de SSH e SG de aplicação (defesa em profundidade). Minimizar IAM Policies (substituir gerenciadas por políticas customizadas com ações estritas).
- **Escalabilidade**: Estrutura já preparada para multi-subnet, permitindo adicionar ALB e Auto Scaling Group futuramente.
- **Observabilidade**: Adicionar CloudWatch Logs config e métricas customizadas em iteração futura.

## Fluxos de Trabalho

### Desenvolvimento Local

```bash
# Compilar a aplicação Java
cd app
mvn clean package

# Verificar infraestrutura Terraform
cd ../terraform
terraform fmt
terraform validate
terraform plan
```

### Deploy da Aplicação

```bash
# Provisionar infraestrutura
cd terraform
terraform apply -auto-approve

# Empacotar aplicação para deploy
cd ../app
mvn clean package

# Deploy via CodeDeploy (usando o script de helper)
cd ../scripts
./deploy_application.sh
```

## Padrões e Convenções

1. **Endpoints REST**: JSON simples, status 200.
2. **Código Terraform**: 
  - Módulos: vpc, ec2, codedeploy.
  - Variáveis explícitas (sem valores embutidos) exceto defaults documentados.
  - Tags obrigatórias: Name, Environment, ManagedBy.
  - Evitar duplicação de lógica (ex: lista de subnets derivada por `count`).
3. **Scripts de Automação**:
  - Permissões de execução (`chmod +x`).
  - Logs em /var/log.
  - `set -e` para fail-fast.
4. **Security Groups**:
  - Porta 22 e 8080 somente para `allowed_cidr`.
  - Recomendado separar em dois SGs em evolução.
5. **Variáveis Principais**:
  - `allowed_cidr`: restringe acesso (default 0.0.0.0/0 – mudar em produção).
  - `public_subnet_count`: número de subnets públicas (default 2).
  - `subnet_index`: índice usado como fallback quando `instance_count=1`.
  - `instance_count`: número de instâncias EC2 (distribuição round-robin nas subnets).
  - `http_port` / `ssh_port`.
  - `allowed_cidr_ssh` / `allowed_cidr_http`.
  - `key_name`: chave SSH existente.
  - `instance_type`: t2.micro no Free Tier.

## Dicas para Solução de Problemas

- **Aplicação Java**: `/var/log/app.log` ou `journalctl -u contador-app -f` (systemd).
- **CodeDeploy**: `/var/log/aws/codedeploy-agent/codedeploy-agent.log` e `/opt/codedeploy-agent/deployment-root/`.
- **Terraform**: `terraform output` para IPs/DNS. `TF_LOG=INFO` em caso de diagnóstico.
- **Portas Bloqueadas**: Revisar `allowed_cidr_*` e SG.
- **Falha em Deployment**: Checar hooks (BeforeInstall/AfterInstall/ApplicationStart/ValidateService) e status do agente.
- **Multi-instância não recebe deploy**: Ajustar filtro do Deployment Group para tag comum (ex. Role=app) ou KEY_ONLY.
- **SSH Negado**: Confirmar chave e IP origem; considerar Session Manager.

## Melhorias Futuras Planejáveis
- Separar SGs (SSH vs App) e restringir SSH a bastion/SSM.
- Adicionar Session Manager (já com política SSM) e desabilitar SSH.
- CloudWatch Logs/metrics e alarmes (erros HTTP, memória, CPU).
- Pipeline CI/CD automatizado.
- Substituir política AmazonEC2RoleforAWSCodeDeploy por política mínima custom.
- Implementar ALB + Auto Scaling.
- Ajustar filtro CodeDeploy para suportar múltiplas instâncias (tag Role).
- Adicionar backend remoto Terraform.