#!/bin/bash

# quick-deploy.sh
# Deploy rápido com opção de escolher deployment groups

set -e

# Configurar profile e região AWS
export AWS_PROFILE="alm-yahoo-account"
export AWS_DEFAULT_REGION="us-east-1"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
info() { echo -e "${BLUE}$1${NC}"; }
warning() { echo -e "${YELLOW}$1${NC}"; }

# Função para escolher deployment groups
choose_deployment_groups() {
    log "🎯 Escolhendo deployment groups..."
    
    cd terraform
    ALL_GROUPS=$(terraform output -json codedeploy_deployment_group_names 2>/dev/null || echo "{}")
    cd ..
    
    # Extrair lista de deployment groups
    local groups_string=$(echo "$ALL_GROUPS" | jq -r 'to_entries[] | .value' | tr '\n' ' ')
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
                info "✓ Selecionado: Todos os deployment groups (${#groups[@]} grupos)"
            else
                # Grupo específico
                SELECTED_GROUPS=("${groups[$((choice-1))]}")
                info "✓ Selecionado: ${groups[$((choice-1))]}"
            fi
            break
        else
            warning "Opção inválida. Digite um número entre 1 e $((${#groups[@]}+1))."
        fi
    done
    
    echo ""
}

log "🚀 Deploy Rápido Iniciado"

# 1. Build
log "Compilando..."
cd app && mvn package -DskipTests -q && cd ..

# 2. Empacotar
log "Empacotando..."
rm -rf temp-deploy && mkdir temp-deploy
cp app/target/app-0.0.1-SNAPSHOT.jar temp-deploy/
cp app/appspec.yml temp-deploy/
# Copiar diretório scripts completo
cp -r scripts temp-deploy/
cd temp-deploy && zip -r ../quick-deploy.zip . > /dev/null && cd .. && rm -rf temp-deploy

# 3. Escolher deployment groups
choose_deployment_groups

# 4. Upload e Deploy
log "Fazendo deploy..."
cd terraform
APP_NAME=$(terraform output -raw codedeploy_application_name)
BUCKET=$(terraform output -raw s3_bucket_name)
cd ..

S3_KEY="quick-deploy/$(date +%Y%m%d-%H%M%S).zip"
aws s3 cp quick-deploy.zip "s3://$BUCKET/$S3_KEY" --quiet

# Array para deployment IDs
DEPLOY_IDS=()

# Criar deployments para cada grupo selecionado
for group in "${SELECTED_GROUPS[@]}"; do
    log "Criando deployment para: $group"
    
    DEPLOY_ID=$(aws deploy create-deployment \
        --application-name "$APP_NAME" \
        --deployment-group-name "$group" \
        --s3-location bucket="$BUCKET",key="$S3_KEY",bundleType=zip \
        --description "Deploy rápido $(date +%H:%M:%S) - Grupo: $group" \
        --query 'deploymentId' --output text)
    
    DEPLOY_IDS+=("$DEPLOY_ID")
    info "Deployment ID para $group: $DEPLOY_ID"
done

log "Monitorando ${#DEPLOY_IDS[@]} deployment(s)... (Ctrl+C para sair)"

# Monitor múltiplos deployments - compatível com bash do macOS
completed=0
total=${#DEPLOY_IDS[@]}

while [ $completed -lt $total ]; do
    sleep 10
    
    for i in "${!DEPLOY_IDS[@]}"; do
        deploy_id="${DEPLOY_IDS[$i]}"
        group="${SELECTED_GROUPS[$i]}"
        
        # Usar arquivo temporário para controle de status
        status_file="/tmp/deploy_status_${deploy_id}"
        
        if [ ! -f "$status_file" ] || [ "$(cat "$status_file" 2>/dev/null)" = "InProgress" ]; then
            STATUS=$(aws deploy get-deployment --deployment-id "$deploy_id" --query 'deploymentInfo.status' --output text)
            echo "$STATUS" > "$status_file"
            
            if [ "$STATUS" != "InProgress" ]; then
                completed=$((completed + 1))
                
                case $STATUS in
                    "Succeeded")
                        log "✅ Deploy concluído: $group"
                        ;;
                    "Failed"|"Stopped")
                        error "❌ Deploy falhou: $group"
                        ;;
                esac
            fi
        fi
    done
    
    if [ $completed -lt $total ]; then
        echo -n "."
    fi
done

echo ""

# Verificar resultados finais
failed=0
for i in "${!DEPLOY_IDS[@]}"; do
    deploy_id="${DEPLOY_IDS[$i]}"
    status_file="/tmp/deploy_status_${deploy_id}"
    status=$(cat "$status_file" 2>/dev/null || echo "Unknown")
    
    if [ "$status" != "Succeeded" ]; then
        failed=$((failed + 1))
    fi
    
    # Limpar arquivo temporário
    rm -f "$status_file"
done

if [ $failed -eq 0 ]; then
    log "🎉 Todos os deployments concluídos com sucesso!"
    rm -f quick-deploy.zip
    echo ""
    info "Teste os endpoints:"
    terraform output -raw instance_public_ips | jq -r '.[]' | head -1 | xargs -I {} echo "  curl http://{}:8080/healthcheck"
else
    error "❌ $failed deployment(s) falharam!"
    exit 1
fi
