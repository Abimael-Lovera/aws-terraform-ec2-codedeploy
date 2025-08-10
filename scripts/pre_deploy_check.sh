#!/bin/bash

# pre_deploy_check.sh
# Script para validar se tudo está pronto para o deploy da infraestrutura e aplicação

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Contadores
checks_passed=0
checks_failed=0
checks_warnings=0

# Função para verificar um item
check_item() {
    local description="$1"
    local command="$2"
    local is_critical="${3:-true}"
    
    echo -n "🔍 Verificando: $description... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo "✅"
        checks_passed=$((checks_passed + 1))
        return 0
    else
        if [ "$is_critical" = "true" ]; then
            echo "❌"
            checks_failed=$((checks_failed + 1))
            return 1
        else
            echo "⚠️"
            checks_warnings=$((checks_warnings + 1))
            return 0
        fi
    fi
}

# Função principal de verificação
main() {
    log "=== VERIFICAÇÃO PRÉ-DEPLOY ==="
    echo ""
    
    # 1. Verificar dependências do sistema
    log "📦 Verificando dependências do sistema..."
    check_item "AWS CLI instalado" "command -v aws"
    check_item "Terraform instalado" "command -v terraform"
    check_item "Maven instalado" "command -v mvn"
    check_item "Java instalado" "command -v java"
    check_item "jq instalado" "command -v jq"
    echo ""
    
    # 2. Verificar estrutura do projeto
    log "📁 Verificando estrutura do projeto..."
    check_item "Diretório terraform existe" "[ -d terraform ]"
    check_item "Diretório app existe" "[ -d app ]"
    check_item "Diretório scripts existe" "[ -d scripts ]"
    check_item "Arquivo appspec.yml existe" "[ -f app/appspec.yml ]"
    check_item "Arquivo pom.xml existe" "[ -f app/pom.xml ]"
    echo ""
    
    # 3. Verificar arquivos Terraform
    log "🏗️ Verificando configuração Terraform..."
    check_item "main.tf existe" "[ -f terraform/main.tf ]"
    check_item "variables.tf existe" "[ -f terraform/variables.tf ]"
    check_item "outputs.tf existe" "[ -f terraform/outputs.tf ]"
    check_item "providers.tf existe" "[ -f terraform/providers.tf ]"
    check_item "terraform.tfvars existe" "[ -f terraform/terraform.tfvars ]"
    echo ""
    
    # 4. Verificar módulos Terraform
    log "📋 Verificando módulos Terraform..."
    check_item "Módulo VPC existe" "[ -d terraform/modules/vpc ]"
    check_item "Módulo EC2 existe" "[ -d terraform/modules/ec2 ]"
    check_item "Módulo CodeDeploy existe" "[ -d terraform/modules/codedeploy ]"
    check_item "Outputs VPC definidos" "[ -f terraform/modules/vpc/outputs.tf ]"
    check_item "Outputs EC2 definidos" "[ -f terraform/modules/ec2/outputs.tf ]"
    check_item "Outputs CodeDeploy definidos" "[ -f terraform/modules/codedeploy/outputs.tf ]"
    echo ""
    
    # 5. Validar sintaxe Terraform
    log "✅ Validando sintaxe Terraform..."
    cd terraform
    if terraform validate >/dev/null 2>&1; then
        success "Configuração Terraform válida"
        checks_passed=$((checks_passed + 1))
    else
        error "Configuração Terraform inválida"
        checks_failed=$((checks_failed + 1))
    fi
    cd ..
    echo ""
    
    # 6. Verificar chave SSH
    log "🔑 Verificando chave SSH..."
    if [ -f "contador-app-key-ssh.pem" ]; then
        success "Chave SSH encontrada"
        
        # Verificar permissões
        perms=$(stat -f "%A" "contador-app-key-ssh.pem" 2>/dev/null || stat -c "%a" "contador-app-key-ssh.pem" 2>/dev/null)
        if [ "$perms" = "600" ]; then
            success "Permissões da chave SSH corretas (600)"
        else
            warning "Permissões da chave SSH: $perms (recomendado: 600)"
            checks_warnings=$((checks_warnings + 1))
        fi
        checks_passed=$((checks_passed + 1))
    else
        error "Chave SSH 'contador-app-key-ssh.pem' não encontrada"
        checks_failed=$((checks_failed + 1))
    fi
    echo ""
    
    # 7. Verificar scripts de deploy
    log "📜 Verificando scripts de deploy..."
    for script in install_dependencies.sh start_application.sh stop_application.sh install_systemd_service.sh validate_service.sh; do
        check_item "Script $script existe" "[ -f scripts/$script ]"
        check_item "Script $script é executável" "[ -x scripts/$script ]"
    done
    echo ""
    
    # 8. Verificar build da aplicação
    log "☕ Verificando aplicação Java..."
    cd app
    if mvn clean package -DskipTests >/dev/null 2>&1; then
        success "Aplicação Java compila com sucesso"
        checks_passed=$((checks_passed + 1))
        
        if [ -f "target/app-0.0.1-SNAPSHOT.jar" ]; then
            success "JAR da aplicação criado"
            checks_passed=$((checks_passed + 1))
        else
            error "JAR da aplicação não foi criado"
            checks_failed=$((checks_failed + 1))
        fi
    else
        error "Falha na compilação da aplicação Java"
        checks_failed=$((checks_failed + 1))
    fi
    cd ..
    echo ""
    
    # 9. Verificar configurações AWS
    log "☁️ Verificando configuração AWS..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        success "AWS CLI configurado e autenticado"
        checks_passed=$((checks_passed + 1))
        
        # Mostrar conta e região
        account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        region=$(aws configure get region 2>/dev/null || echo "us-east-1")
        info "Conta AWS: $account_id"
        info "Região: $region"
    else
        error "AWS CLI não configurado ou sem permissões"
        checks_failed=$((checks_failed + 1))
    fi
    echo ""
    
    # 10. Verificar scripts de automação
    log "🤖 Verificando scripts de automação..."
    check_item "Script validate_instances.sh existe" "[ -f scripts/validate_instances.sh ]"
    check_item "Script deploy_and_validate.sh existe" "[ -f scripts/deploy_and_validate.sh ]"
    check_item "Script health_monitor.sh existe" "[ -f scripts/health_monitor.sh ]"
    check_item "Script package_revision.sh existe" "[ -f scripts/package_revision.sh ]"
    echo ""
    
    # Relatório final
    log "=== RELATÓRIO FINAL ==="
    success "Verificações passaram: $checks_passed"
    if [ $checks_warnings -gt 0 ]; then
        warning "Avisos: $checks_warnings"
    fi
    if [ $checks_failed -gt 0 ]; then
        error "Verificações falharam: $checks_failed"
    fi
    
    echo ""
    if [ $checks_failed -eq 0 ]; then
        success "🎉 PROJETO PRONTO PARA DEPLOY!"
        echo ""
        info "Próximos passos:"
        echo "  1. terraform apply"
        echo "  2. ./scripts/deploy_and_validate.sh"
        echo "  3. ./scripts/health_monitor.sh status"
        exit 0
    else
        error "❌ PROJETO NÃO ESTÁ PRONTO PARA DEPLOY"
        echo ""
        error "Corrija os problemas acima antes de prosseguir."
        exit 1
    fi
}

# Função de ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Script de verificação pré-deploy para validar se o projeto está"
    echo "pronto para deploy da infraestrutura e aplicação."
    echo ""
    echo "Opções:"
    echo "  -h, --help     Mostra esta ajuda"
    echo "  -v, --verbose  Modo verboso (mostra detalhes dos comandos)"
    echo ""
    echo "Verificações realizadas:"
    echo "  ✓ Dependências do sistema (AWS CLI, Terraform, Maven, Java, jq)"
    echo "  ✓ Estrutura do projeto"
    echo "  ✓ Configuração e módulos Terraform"
    echo "  ✓ Chave SSH"
    echo "  ✓ Scripts de deploy"
    echo "  ✓ Compilação da aplicação Java"
    echo "  ✓ Configuração AWS"
    echo "  ✓ Scripts de automação"
}

# Parse de argumentos
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        set -x
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

# Executar verificação principal
main
