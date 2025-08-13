#!/bin/bash

# deploy.sh
# Script simples para deploy da aplicação Spring Boot via AWS CodeDeploy

set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
AWS_PROFILE="alm-yahoo-account"  # Profile AWS a ser usado
AWS_DEFAULT_REGION="us-east-1"  # Região AWS
export AWS_PROFILE AWS_DEFAULT_REGION

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de log
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

# Função para verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI não encontrado. Instale o AWS CLI primeiro."
        exit 1
    fi
    
    # Verificar Maven
    if ! command -v mvn &> /dev/null; then
        error "Maven não encontrado. Instale o Maven primeiro."
        exit 1
    fi
    
    # Verificar Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform não encontrado. Instale o Terraform primeiro."
        exit 1
    fi
    
    # Verificar se está no diretório correto
    if [ ! -f "$PROJECT_ROOT/app/pom.xml" ]; then
        error "Arquivo pom.xml não encontrado. Execute o script na raiz do projeto."
        exit 1
    fi
    
    # Verificar se infra está deployada
    if [ ! -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]; then
        error "Infraestrutura não encontrada. Execute 'terraform apply' primeiro."
        exit 1
    fi
    
    log "✓ Todas as dependências verificadas"
}

# Função para build da aplicação
build_app() {
    log "=== COMPILANDO APLICAÇÃO ==="
    
    cd "$PROJECT_ROOT/app"
    
    log "Executando testes..."
    if ! mvn test -q; then
        error "Testes falharam!"
        exit 1
    fi
    
    log "Compilando aplicação..."
    if ! mvn package -DskipTests -q; then
        error "Compilação falhou!"
        exit 1
    fi
    
    if [ ! -f "target/app-0.0.1-SNAPSHOT.jar" ]; then
        error "JAR não foi criado!"
        exit 1
    fi
    
    log "✓ Aplicação compilada com sucesso"
    cd "$PROJECT_ROOT"
}

# Função para criar pacote de deploy
create_package() {
    log "=== CRIANDO PACOTE DE DEPLOY ==="
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local package_dir="deploy-package-$timestamp"
    
    # Criar diretório temporário
    rm -rf deploy-package-*
    mkdir -p "$package_dir"
    
    # Copiar arquivos necessários
    cp app/target/app-0.0.1-SNAPSHOT.jar "$package_dir/"
    cp app/appspec.yml "$package_dir/"
    cp -r scripts/ "$package_dir/"
    
    # Criar ZIP
    cd "$package_dir"
    zip -r ../deploy-package.zip . > /dev/null
    cd "$PROJECT_ROOT"
    
    # Limpar diretório temporário
    rm -rf "$package_dir"
    
    log "✓ Pacote criado: deploy-package.zip"
}

# Função para obter configurações do Terraform
get_terraform_config() {
    log "=== OBTENDO CONFIGURAÇÕES ==="
    
    cd "$PROJECT_ROOT/terraform"
    
    # Verificar se terraform foi inicializado
    if [ ! -d ".terraform" ]; then
        error "Terraform não inicializado. Execute 'terraform init' primeiro."
        exit 1
    fi
    
    # Obter outputs
    APP_NAME=$(terraform output -raw codedeploy_application_name 2>/dev/null || echo "")
    BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    
    # Obter todos os deployment groups
    ALL_DEPLOYMENT_GROUPS=$(terraform output -json codedeploy_deployment_group_names 2>/dev/null || echo "{}")
    
    if [ -z "$APP_NAME" ] || [ -z "$BUCKET_NAME" ] || [ "$ALL_DEPLOYMENT_GROUPS" = "{}" ]; then
        error "Não foi possível obter configurações do CodeDeploy."
        echo "Verifique se a infraestrutura foi aplicada corretamente."
        exit 1
    fi
    
    info "Aplicação: $APP_NAME"
    info "Bucket S3: $BUCKET_NAME"
    
    cd "$PROJECT_ROOT"
}

# Função para escolher deployment groups
choose_deployment_groups() {
    log "=== ESCOLHENDO DEPLOYMENT GROUPS ==="
    
    # Extrair lista de deployment groups
    local groups_string=$(echo "$ALL_DEPLOYMENT_GROUPS" | jq -r 'to_entries[] | .value' | tr '\n' ' ')
    read -ra groups <<< "$groups_string"
    
    if [ ${#groups[@]} -eq 0 ]; then
        error "Nenhum deployment group encontrado!"
        exit 1
    fi
    
    echo ""
    echo "Deployment Groups disponíveis:"
    for i in "${!groups[@]}"; do
        echo "  $((i+1)). ${groups[$i]}"
    done
    echo "  $((${#groups[@]}+1)). Todos os deployment groups"
    echo ""
    
    while true; do
        read -p "Escolha uma opção (1-$((${#groups[@]}+1))): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((${#groups[@]}+1)) ]; then
            if [ "$choice" -eq $((${#groups[@]}+1)) ]; then
                # Todos os grupos
                SELECTED_GROUPS=("${groups[@]}")
                DEPLOY_ALL=true
                info "✓ Selecionado: Todos os deployment groups (${#groups[@]} grupos)"
            else
                # Grupo específico
                SELECTED_GROUPS=("${groups[$((choice-1))]}")
                DEPLOY_ALL=false
                info "✓ Selecionado: ${groups[$((choice-1))]}"
            fi
            break
        else
            warning "Opção inválida. Digite um número entre 1 e $((${#groups[@]}+1))."
        fi
    done
    
    echo ""
}

# Função para fazer upload e deploy
deploy_to_codedeploy() {
    log "=== FAZENDO DEPLOY ==="
    
    local s3_key="deployments/app-$(date +%Y%m%d-%H%M%S).zip"
    
    # Upload para S3
    log "Fazendo upload para S3..."
    if ! aws s3 cp deploy-package.zip "s3://$BUCKET_NAME/$s3_key" --quiet; then
        error "Falha no upload para S3"
        exit 1
    fi
    
    log "✓ Upload concluído: s3://$BUCKET_NAME/$s3_key"
    
    # Array para armazenar deployment IDs
    DEPLOYMENT_IDS=()
    
    # Criar deployments para cada grupo selecionado
    for group in "${SELECTED_GROUPS[@]}"; do
        log "Iniciando deployment no grupo: $group"
        
        DEPLOYMENT_ID=$(aws deploy create-deployment \
            --application-name "$APP_NAME" \
            --deployment-group-name "$group" \
            --s3-location bucket="$BUCKET_NAME",key="$s3_key",bundleType=zip \
            --description "Deploy automático - $(date) - Grupo: $group" \
            --query 'deploymentId' \
            --output text)
        
        if [ -z "$DEPLOYMENT_ID" ]; then
            error "Falha ao criar deployment para o grupo $group"
            exit 1
        fi
        
        DEPLOYMENT_IDS+=("$DEPLOYMENT_ID")
        info "Deployment ID para $group: $DEPLOYMENT_ID"
    done
    
    # Monitorar todos os deployments
    monitor_deployments
}

# Função para monitorar múltiplos deployments
monitor_deployments() {
    log "=== MONITORANDO DEPLOYMENTS ==="
    
    local total_deployments=${#DEPLOYMENT_IDS[@]}
    local completed_deployments=0
    local failed_deployments=0
    local attempts=0
    local max_attempts=20  # 10 minutos
    
    while [ $completed_deployments -lt $total_deployments ] && [ $attempts -lt $max_attempts ]; do
        sleep 30
        attempts=$((attempts + 1))
        
        for i in "${!DEPLOYMENT_IDS[@]}"; do
            local deployment_id="${DEPLOYMENT_IDS[$i]}"
            local group="${SELECTED_GROUPS[$i]}"
            
            # Usar arquivo temporário para controle de status
            local status_file="/tmp/deploy_status_${deployment_id}"
            
            if [ ! -f "$status_file" ] || [ "$(cat "$status_file" 2>/dev/null)" = "InProgress" ]; then
                local status=$(aws deploy get-deployment \
                    --deployment-id "$deployment_id" \
                    --query 'deploymentInfo.status' \
                    --output text)
                
                echo "$status" > "$status_file"
                
                if [ "$status" != "InProgress" ]; then
                    completed_deployments=$((completed_deployments + 1))
                    
                    if [ "$status" = "Succeeded" ]; then
                        log "✅ Deployment concluído com sucesso: $group"
                    else
                        error "❌ Deployment falhou: $group ($status)"
                        failed_deployments=$((failed_deployments + 1))
                    fi
                fi
            fi
        done
        
        info "Progresso: $completed_deployments/$total_deployments concluídos ($attempts/$max_attempts tentativas)"
    done
    
    # Resultados finais
    echo ""
    if [ $failed_deployments -eq 0 ] && [ $completed_deployments -eq $total_deployments ]; then
        log "🎉 TODOS OS DEPLOYMENTS CONCLUÍDOS COM SUCESSO!"
        
        # Limpar arquivos temporários
        rm -f deploy-package.zip
        for deployment_id in "${DEPLOYMENT_IDS[@]}"; do
            rm -f "/tmp/deploy_status_${deployment_id}"
        done
        
        # Sugerir validação
        echo ""
        warning "Para validar os deployments, execute:"
        echo "  ./validate_instances.sh"
        echo ""
        warning "Para testar os endpoints:"
        echo "  curl http://<IP_INSTANCIA>:8080/healthcheck"
        echo "  curl http://<IP_INSTANCIA>:8080/contador"
        
    else
        if [ $failed_deployments -gt 0 ]; then
            error "❌ $failed_deployments DEPLOYMENT(S) FALHARAM!"
            
            # Mostrar detalhes dos erros
            for i in "${!DEPLOYMENT_IDS[@]}"; do
                local deployment_id="${DEPLOYMENT_IDS[$i]}"
                local group="${SELECTED_GROUPS[$i]}"
                local status_file="/tmp/deploy_status_${deployment_id}"
                local status=$(cat "$status_file" 2>/dev/null || echo "Unknown")
                
                if [ "$status" = "Failed" ] || [ "$status" = "Stopped" ]; then
                    echo ""
                    error "Detalhes do erro para $group:"
                    aws deploy get-deployment \
                        --deployment-id "$deployment_id" \
                        --query 'deploymentInfo.errorInformation' \
                        --output table 2>/dev/null || true
                fi
            done
        fi
        
        if [ $completed_deployments -lt $total_deployments ]; then
            warning "⏰ Timeout - Alguns deployments ainda em progresso"
            echo ""
            info "IDs dos deployments para verificação manual:"
            for i in "${!DEPLOYMENT_IDS[@]}"; do
                local deployment_id="${DEPLOYMENT_IDS[$i]}"
                local group="${SELECTED_GROUPS[$i]}"
                echo "  $group: $deployment_id"
            done
        fi
        
        # Limpar arquivos temporários
        for deployment_id in "${DEPLOYMENT_IDS[@]}"; do
            rm -f "/tmp/deploy_status_${deployment_id}"
        done
        
        exit 1
    fi
}

# Função principal
main() {
    log "🚀 INICIANDO DEPLOY DA APLICAÇÃO CONTADOR"
    echo ""
    
    check_dependencies
    echo ""
    
    build_app
    echo ""
    
    create_package
    echo ""
    
    get_terraform_config
    echo ""
    
    choose_deployment_groups
    echo ""
    
    deploy_to_codedeploy
    echo ""
    
    log "✅ DEPLOY FINALIZADO!"
}

# Executar script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
