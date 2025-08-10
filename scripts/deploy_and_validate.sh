#!/bin/bash

# deploy_and_validate.sh
# Script para automatizar deploy e validação completa da aplicação
# Combina empacotamento, deploy via CodeDeploy e validação das instâncias

set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KEY_FILE="contador-app-key-ssh.pem"
USER="ec2-user"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

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

# Função para build da aplicação
build_application() {
    log "=== FASE 1: BUILD DA APLICAÇÃO ==="
    
    cd "$PROJECT_ROOT/app"
    
    log "Limpando build anterior..."
    mvn clean > /dev/null 2>&1
    
    log "Executando testes..."
    if ! mvn test; then
        error "Testes falharam! Deploy não será executado."
        exit 1
    fi
    
    log "Compilando aplicação..."
    if ! mvn package -DskipTests; then
        error "Falha na compilação da aplicação"
        exit 1
    fi
    
    # Verificar se JAR foi criado
    if [ ! -f "target/app-0.0.1-SNAPSHOT.jar" ]; then
        error "Arquivo JAR não foi criado"
        exit 1
    fi
    
    log "✓ Build da aplicação concluído com sucesso"
    echo ""
}

# Função para criar revisão do CodeDeploy
create_revision() {
    log "=== FASE 2: CRIAÇÃO DA REVISÃO ==="
    
    cd "$PROJECT_ROOT"
    
    # Usar o script existente de empacotamento
    if [ -f "scripts/package_revision.sh" ]; then
        log "Executando script de empacotamento..."
        if ! bash scripts/package_revision.sh; then
            error "Falha no empacotamento da revisão"
            exit 1
        fi
    else
        # Criar revisão manualmente se script não existir
        log "Criando revisão manualmente..."
        
        REVISION_DIR="revision"
        rm -rf "$REVISION_DIR"
        mkdir -p "$REVISION_DIR"
        
        # Copiar arquivos necessários
        cp app/target/app-0.0.1-SNAPSHOT.jar "$REVISION_DIR/"
        cp app/appspec.yml "$REVISION_DIR/"
        cp -r scripts/ "$REVISION_DIR/"
        
        # Criar arquivo ZIP
        cd "$REVISION_DIR"
        zip -r ../revision.zip . > /dev/null
        cd ..
        rm -rf "$REVISION_DIR"
    fi
    
    log "✓ Revisão criada com sucesso"
    echo ""
}

# Função para fazer deploy via CodeDeploy
deploy_application() {
    log "=== FASE 3: DEPLOY VIA CODEDEPLOY ==="
    
    cd "$PROJECT_ROOT/terraform"
    
    # Obter configurações do Terraform
    local app_name
    local deployment_group
    local bucket_name
    
    app_name=$(terraform output -raw codedeploy_application_name 2>/dev/null || echo "")
    deployment_group=$(terraform output -raw codedeploy_deployment_group_name 2>/dev/null || echo "")
    bucket_name=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
    
    if [ -z "$app_name" ] || [ -z "$deployment_group" ] || [ -z "$bucket_name" ]; then
        error "Não foi possível obter configurações do CodeDeploy do Terraform"
        echo "Outputs necessários: codedeploy_application_name, codedeploy_deployment_group_name, s3_bucket_name"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    
    info "Aplicação CodeDeploy: $app_name"
    info "Deployment Group: $deployment_group"
    info "Bucket S3: $bucket_name"
    
    # Upload da revisão para S3
    local s3_key="revisions/revision-$(date +%Y%m%d-%H%M%S).zip"
    
    log "Fazendo upload da revisão para S3..."
    if ! aws s3 cp revision.zip "s3://$bucket_name/$s3_key"; then
        error "Falha no upload para S3"
        exit 1
    fi
    
    log "✓ Upload para S3 concluído: s3://$bucket_name/$s3_key"
    
    # Criar deployment
    log "Iniciando deployment..."
    local deployment_id
    deployment_id=$(aws deploy create-deployment \
        --application-name "$app_name" \
        --deployment-group-name "$deployment_group" \
        --s3-location bucket="$bucket_name",key="$s3_key",bundleType=zip \
        --description "Deploy automatizado em $(date)" \
        --query 'deploymentId' \
        --output text)
    
    if [ -z "$deployment_id" ]; then
        error "Falha ao criar deployment"
        exit 1
    fi
    
    info "Deployment criado com ID: $deployment_id"
    
    # Monitorar deployment
    log "Monitorando progresso do deployment..."
    local status="InProgress"
    local attempts=0
    local max_attempts=30  # 15 minutos máximo
    
    while [ "$status" = "InProgress" ] && [ $attempts -lt $max_attempts ]; do
        sleep 30
        attempts=$((attempts + 1))
        
        status=$(aws deploy get-deployment \
            --deployment-id "$deployment_id" \
            --query 'deploymentInfo.status' \
            --output text)
        
        info "Status do deployment: $status (tentativa $attempts/$max_attempts)"
        
        # Mostrar detalhes se houver falha
        if [ "$status" = "Failed" ] || [ "$status" = "Stopped" ]; then
            error "Deployment falhou!"
            
            # Obter detalhes do erro
            local error_info
            error_info=$(aws deploy get-deployment \
                --deployment-id "$deployment_id" \
                --query 'deploymentInfo.errorInformation' \
                --output text 2>/dev/null || echo "Erro não disponível")
            
            if [ "$error_info" != "None" ] && [ "$error_info" != "Erro não disponível" ]; then
                error "Detalhes do erro: $error_info"
            fi
            
            # Listar instâncias com falha
            log "Verificando status das instâncias..."
            aws deploy list-deployment-instances \
                --deployment-id "$deployment_id" \
                --output table
                
            exit 1
        fi
    done
    
    if [ $attempts -ge $max_attempts ]; then
        error "Timeout no deployment após $max_attempts tentativas"
        exit 1
    fi
    
    if [ "$status" = "Succeeded" ]; then
        log "✓ Deployment concluído com sucesso!"
    else
        error "Deployment terminou com status: $status"
        exit 1
    fi
    
    echo ""
}

# Função para validar aplicação deployada
validate_deployment() {
    log "=== FASE 4: VALIDAÇÃO DA APLICAÇÃO ==="
    
    cd "$PROJECT_ROOT/terraform"
    
    # Obter IPs das instâncias
    local instance_ips
    instance_ips=$(terraform output -json instance_public_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
    
    if [ -z "$instance_ips" ]; then
        error "Não foi possível obter IPs das instâncias"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    
    local success_count=0
    local total_count=0
    
    for ip in $instance_ips; do
        total_count=$((total_count + 1))
        
        log "Validando instância $ip..."
        
        # Aguardar aplicação estar rodando
        local app_ready=false
        local wait_attempts=0
        local max_wait=20  # 10 minutos
        
        while [ "$app_ready" = false ] && [ $wait_attempts -lt $max_wait ]; do
            wait_attempts=$((wait_attempts + 1))
            
            if timeout 10 ssh $SSH_OPTIONS -i "$KEY_FILE" "$USER@$ip" "curl -s http://localhost:8080/healthcheck" > /dev/null 2>&1; then
                app_ready=true
                break
            fi
            
            info "Aguardando aplicação estar pronta... (tentativa $wait_attempts/$max_wait)"
            sleep 30
        done
        
        if [ "$app_ready" = false ]; then
            error "Timeout aguardando aplicação na instância $ip"
            continue
        fi
        
        # Testar endpoints
        log "Testando endpoints na instância $ip..."
        
        # Teste /healthcheck
        local health_response
        health_response=$(timeout 10 ssh $SSH_OPTIONS -i "$KEY_FILE" "$USER@$ip" "curl -s http://localhost:8080/healthcheck" 2>/dev/null || echo "ERRO")
        
        if echo "$health_response" | grep -q "OK"; then
            echo "✓ Endpoint /healthcheck: OK"
        else
            error "Endpoint /healthcheck falhou: $health_response"
            continue
        fi
        
        # Teste /contador
        local counter_response
        counter_response=$(timeout 10 ssh $SSH_OPTIONS -i "$KEY_FILE" "$USER@$ip" "curl -s http://localhost:8080/contador" 2>/dev/null || echo "ERRO")
        
        if echo "$counter_response" | grep -q "contador"; then
            echo "✓ Endpoint /contador: $counter_response"
        else
            error "Endpoint /contador falhou: $counter_response"
            continue
        fi
        
        # Verificar logs da aplicação
        local app_logs
        app_logs=$(timeout 10 ssh $SSH_OPTIONS -i "$KEY_FILE" "$USER@$ip" "sudo tail -5 /var/log/app.log" 2>/dev/null || echo "Logs não disponíveis")
        
        if [ "$app_logs" != "Logs não disponíveis" ]; then
            info "Últimas linhas do log da aplicação:"
            echo "$app_logs"
        fi
        
        success_count=$((success_count + 1))
        log "✓ Instância $ip validada com sucesso"
        echo ""
    done
    
    # Relatório final
    log "=== RELATÓRIO FINAL DE VALIDAÇÃO ==="
    log "Total de instâncias: $total_count"
    log "Instâncias validadas: $success_count"
    
    if [ $success_count -eq $total_count ]; then
        log "🎉 Deploy e validação concluídos com sucesso!"
        
        # Mostrar URLs de acesso
        log "URLs de acesso à aplicação:"
        for ip in $instance_ips; do
            echo "  http://$ip:8080/healthcheck"
            echo "  http://$ip:8080/contador"
        done
        
        return 0
    else
        error "❌ Falha na validação de algumas instâncias"
        return 1
    fi
}

# Função para limpeza
cleanup() {
    log "Limpando arquivos temporários..."
    rm -f "$PROJECT_ROOT/revision.zip"
}

# Função de ajuda
show_help() {
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Este script automatiza o processo completo de deploy e validação:"
    echo "  1. Build da aplicação Spring Boot"
    echo "  2. Criação da revisão para CodeDeploy"
    echo "  3. Deploy via AWS CodeDeploy"
    echo "  4. Validação dos endpoints da aplicação"
    echo ""
    echo "Opções:"
    echo "  -h, --help     Mostra esta ajuda"
    echo "  --build-only   Executa apenas o build da aplicação"
    echo "  --deploy-only  Executa apenas o deploy (assume build já feito)"
    echo "  --validate-only Executa apenas a validação"
    echo ""
    echo "Pré-requisitos:"
    echo "  - AWS CLI configurado"
    echo "  - Terraform com estado válido"
    echo "  - Chave SSH '$KEY_FILE' no diretório raiz"
    echo "  - Maven instalado"
    echo "  - jq instalado"
}

# Função principal
main() {
    local build_only=false
    local deploy_only=false
    local validate_only=false
    
    # Parse de argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --build-only)
                build_only=true
                shift
                ;;
            --deploy-only)
                deploy_only=true
                shift
                ;;
            --validate-only)
                validate_only=true
                shift
                ;;
            *)
                error "Opção inválida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Verificar dependências
    local missing_deps=""
    
    if ! command -v mvn > /dev/null 2>&1; then
        missing_deps="$missing_deps maven"
    fi
    
    if ! command -v aws > /dev/null 2>&1; then
        missing_deps="$missing_deps aws-cli"
    fi
    
    if ! command -v terraform > /dev/null 2>&1; then
        missing_deps="$missing_deps terraform"
    fi
    
    if ! command -v jq > /dev/null 2>&1; then
        missing_deps="$missing_deps jq"
    fi
    
    if [ -n "$missing_deps" ]; then
        error "Dependências não encontradas:$missing_deps"
        echo "Instale as dependências necessárias primeiro"
        exit 1
    fi
    
    # Verificar chave SSH
    if [ ! -f "$PROJECT_ROOT/$KEY_FILE" ]; then
        error "Chave SSH '$KEY_FILE' não encontrada no diretório raiz"
        exit 1
    fi
    
    # Configurar trap para limpeza
    trap cleanup EXIT
    
    log "Iniciando processo de deploy automatizado..."
    
    # Executar fases baseadas nas opções
    if [ "$validate_only" = true ]; then
        validate_deployment
    elif [ "$build_only" = true ]; then
        build_application
    elif [ "$deploy_only" = true ]; then
        create_revision
        deploy_application
        validate_deployment
    else
        # Processo completo
        build_application
        create_revision
        deploy_application
        validate_deployment
    fi
    
    if [ $? -eq 0 ]; then
        log "🚀 Processo concluído com sucesso!"
    else
        error "❌ Processo falhou"
        exit 1
    fi
}

# Executar função principal
main "$@"
