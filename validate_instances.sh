#!/bin/bash

# validate_instances.sh
# Script para automatizar validação das instâncias EC2 provisionadas
# Este script executa todas as verificações que foram feitas manualmente

set -e

# Configurações
KEY_FILE="contador-app-key-ssh.pem"
USER="ec2-user"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Função para executar comando SSH com timeout
ssh_exec() {
    local host=$1
    local command=$2
    local description=$3
    
    log "Executando: $description em $host"
    timeout 30 ssh $SSH_OPTIONS -i $KEY_FILE $USER@$host "$command"
}

# Função para validar uma instância
validate_instance() {
    local instance_ip=$1
    local instance_name=$2
    
    log "=== Validando instância $instance_name ($instance_ip) ==="
    
    # 1. Teste de conectividade SSH
    log "Testando conectividade SSH..."
    if ! timeout 10 ssh $SSH_OPTIONS -i $KEY_FILE $USER@$instance_ip "echo 'SSH OK'" > /dev/null 2>&1; then
        error "Falha na conectividade SSH para $instance_ip"
        return 1
    fi
    echo "✓ SSH conectividade OK"
    
    # 2. Verificar espaço em disco
    log "Verificando espaço em disco..."
    disk_info=$(ssh_exec $instance_ip "df -h /" "verificação de disco")
    echo "$disk_info"
    
    # Extrair percentual de uso
    disk_usage=$(echo "$disk_info" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ "$disk_usage" =~ ^[0-9]+$ ]] && [ "$disk_usage" -gt 80 ]; then
        warning "Uso de disco alto: ${disk_usage}%"
    else
        echo "✓ Espaço em disco adequado: ${disk_usage}% usado"
    fi
    
    # 3. Verificar versão do Java
    log "Verificando instalação do Java..."
    java_version=$(ssh_exec $instance_ip "java -version 2>&1 | head -1" "versão do Java")
    if echo "$java_version" | grep -q "openjdk version \"17"; then
        echo "✓ Java 17 instalado corretamente"
        echo "  $java_version"
    else
        error "Java 17 não encontrado ou versão incorreta"
        echo "  Encontrado: $java_version"
        return 1
    fi
    
    # 4. Verificar status do CodeDeploy Agent
    log "Verificando CodeDeploy Agent..."
    # Executar comando sem usar ssh_exec para evitar misturar log com output
    log "Executando: status do CodeDeploy em $instance_ip"
    codedeploy_status=$(timeout 30 ssh $SSH_OPTIONS -i $KEY_FILE $USER@$instance_ip "sudo systemctl is-active codedeploy-agent" 2>/dev/null | tr -d '\n\r' | xargs)
    if [ "$codedeploy_status" = "active" ]; then
        echo "✓ CodeDeploy Agent está ativo"
        
        # Verificar se está rodando
        codedeploy_running=$(ssh_exec $instance_ip "sudo systemctl status codedeploy-agent --no-pager -l" "detalhes do CodeDeploy")
        echo "Status detalhado do CodeDeploy:"
        echo "$codedeploy_running" | head -10
    else
        error "CodeDeploy Agent não está ativo: [$codedeploy_status]"
        return 1
    fi
    
    # 5. Verificar usuário appuser
    log "Verificando usuário appuser..."
    if ssh_exec $instance_ip "id appuser" "verificação do usuário appuser" > /dev/null 2>&1; then
        echo "✓ Usuário appuser existe"
        
        # Verificar diretórios da aplicação
        app_dirs=$(ssh_exec $instance_ip "ls -la /opt/app /var/log/ | grep -E '(app|total)'" "diretórios da aplicação")
        echo "Diretórios da aplicação:"
        echo "$app_dirs"
        
        # Verificar permissões
        app_perms=$(ssh_exec $instance_ip "ls -ld /opt/app" "permissões do diretório app")
        if echo "$app_perms" | grep -q "appuser"; then
            echo "✓ Permissões do diretório /opt/app estão corretas"
        else
            warning "Permissões do diretório /opt/app podem estar incorretas"
            echo "  $app_perms"
        fi
    else
        error "Usuário appuser não encontrado"
        return 1
    fi
    
    # 6. Verificar se aplicação já está rodando (opcional)
    log "Verificando se aplicação está rodando..."
    app_status=$(ssh_exec $instance_ip "sudo systemctl is-active contador-app 2>/dev/null || echo 'not-found'" "status da aplicação")
    if [ "$app_status" = "active" ]; then
        echo "✓ Aplicação contador-app está rodando"
        
        # Testar endpoint se aplicação estiver rodando
        if ssh_exec $instance_ip "curl -s http://localhost:8080/healthcheck" "teste do endpoint" > /dev/null 2>&1; then
            echo "✓ Endpoint /healthcheck respondendo"
        else
            warning "Endpoint /healthcheck não está respondendo"
        fi
    elif [ "$app_status" = "not-found" ]; then
        echo "ℹ Aplicação contador-app ainda não foi deployada (normal)"
    else
        warning "Aplicação contador-app não está ativa: $app_status"
    fi
    
    # 7. Verificar recursos do sistema
    log "Verificando recursos do sistema..."
    system_info=$(ssh_exec $instance_ip "free -h && echo '---' && uptime" "recursos do sistema")
    echo "Recursos do sistema:"
    echo "$system_info"
    
    log "=== Validação da instância $instance_name concluída com sucesso ==="
    echo ""
}

# Função principal
main() {
    log "Iniciando validação automatizada das instâncias EC2"
    
    # Verificar se a chave SSH existe
    if [ ! -f "$KEY_FILE" ]; then
        error "Arquivo de chave SSH '$KEY_FILE' não encontrado"
        echo "Certifique-se de que a chave esteja no diretório atual"
        exit 1
    fi
    
    # Verificar permissões da chave
    key_perms=$(stat -f "%A" "$KEY_FILE" 2>/dev/null || stat -c "%a" "$KEY_FILE" 2>/dev/null)
    if [ "$key_perms" != "600" ]; then
        warning "Ajustando permissões da chave SSH"
        chmod 600 "$KEY_FILE"
    fi
    
    # Obter IPs das instâncias do Terraform
    log "Obtendo IPs das instâncias do Terraform..."
    cd terraform
    
    instance_ips=$(terraform output -json instance_public_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
    if [ -z "$instance_ips" ]; then
        error "Não foi possível obter IPs das instâncias do Terraform"
        echo "Execute 'terraform output instance_public_ips' para verificar"
        exit 1
    fi
    
    cd ..
    
    # Validar cada instância
    instance_count=0
    success_count=0
    
    for ip in $instance_ips; do
        instance_count=$((instance_count + 1))
        instance_name="Instance-$instance_count"
        
        if validate_instance "$ip" "$instance_name"; then
            success_count=$((success_count + 1))
        else
            error "Falha na validação da instância $instance_name ($ip)"
        fi
        
        # Adicionar separador entre instâncias
        if [ $instance_count -lt $(echo "$instance_ips" | wc -l) ]; then
            echo "=================================="
        fi
    done
    
    # Relatório final
    echo ""
    log "=== RELATÓRIO FINAL ==="
    log "Total de instâncias: $instance_count"
    log "Instâncias validadas com sucesso: $success_count"
    log "Instâncias com falha: $((instance_count - success_count))"
    
    if [ $success_count -eq $instance_count ]; then
        log "🎉 Todas as instâncias passaram na validação!"
        exit 0
    else
        error "❌ Algumas instâncias falharam na validação"
        exit 1
    fi
}

# Verificar dependências
check_dependencies() {
    local missing_deps=""
    
    if ! command -v jq > /dev/null 2>&1; then
        missing_deps="$missing_deps jq"
    fi
    
    if ! command -v terraform > /dev/null 2>&1; then
        missing_deps="$missing_deps terraform"
    fi
    
    if [ -n "$missing_deps" ]; then
        error "Dependências não encontradas:$missing_deps"
        echo "Instale as dependências necessárias:"
        if echo "$missing_deps" | grep -q "jq"; then
            echo "  brew install jq  # macOS"
        fi
        if echo "$missing_deps" | grep -q "terraform"; then
            echo "  brew install terraform  # macOS"
        fi
        exit 1
    fi
}

# Função de ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Este script automatiza a validação das instâncias EC2 provisionadas."
    echo ""
    echo "Opções:"
    echo "  -h, --help     Mostra esta ajuda"
    echo "  -v, --verbose  Modo verboso (padrão)"
    echo ""
    echo "O script executa as seguintes validações:"
    echo "  ✓ Conectividade SSH"
    echo "  ✓ Espaço em disco disponível"
    echo "  ✓ Instalação do Java 17"
    echo "  ✓ Status do CodeDeploy Agent"
    echo "  ✓ Usuário appuser e diretórios"
    echo "  ✓ Status da aplicação (se deployada)"
    echo "  ✓ Recursos do sistema"
    echo ""
    echo "Pré-requisitos:"
    echo "  - Chave SSH '$KEY_FILE' no diretório atual"
    echo "  - Terraform inicializado com estado válido"
    echo "  - Dependências: jq, terraform"
}

# Parse de argumentos
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        # Já é o padrão
        ;;
    "")
        # Sem argumentos, continuar normalmente
        ;;
    *)
        error "Opção inválida: $1"
        show_help
        exit 1
        ;;
esac

# Executar validações
check_dependencies
main
