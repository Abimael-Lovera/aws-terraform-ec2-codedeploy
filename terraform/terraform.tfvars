# Arquivo de exemplo com valores das variáveis Terraform
# Copie para terraform.tfvars e ajuste conforme seu ambiente.
# NUNCA commit chaves privadas ou dados sensíveis.

# Identidade do projeto
project_name    = "contador-app"
environment      = "dev"
region          = "us-east-1"

# Infra / Instâncias
instance_type    = "t2.micro"        # Free Tier
instance_count   = 2                  # Número de instâncias EC2
subnet_index     = 0                  # Subnet usada se instance_count=1 (fallback)

# Chave SSH existente na AWS (apenas o nome da key pair)
key_name        = "contador-app-key-ssh"

# Portas
http_port       = 8080
ssh_port        = 22

# Controle de acesso (defina IPs específicos sempre que possível)
# allowed_cidr atua como default; allowed_cidr_ssh / allowed_cidr_http sobrescrevem se não vazios
allowed_cidr        = "0.0.0.0/0"        # Evite em produção
allowed_cidr_ssh    = "203.0.113.10/32"  # Seu IP público
allowed_cidr_http   = "0.0.0.0/0"        # App aberto (resstrinja se necessário)

# Observações:
# - Ajuste instance_count >= 2 para distribuir entre subnets públicas.
# - Se alterar quantidade de subnets (no módulo VPC) refaça plan antes.
# - Mantenha allowed_cidr_ssh restrito a um /32 sempre que possível.
# - Para aplicar usando este arquivo: terraform apply -var-file="terraform.tfvars"
