#!/bin/bash

# deploy-all.sh
# Deploy automático em todos os deployment groups sem interação

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

log "🚀 Deploy Automático em Todos os Grupos Iniciado"

# 1. Build
log "Compilando..."
cd app && mvn package -DskipTests -q && cd ..

# 2. Empacotar
log "Empacotando..."
rm -rf temp-deploy && mkdir temp-deploy
cp app/target/app-0.0.1-SNAPSHOT.jar temp-deploy/
cp app/appspec.yml temp-deploy/
cp -r scripts temp-deploy/
cd temp-deploy && zip -r ../deploy-all.zip . > /dev/null && cd .. && rm -rf temp-deploy

# 3. Obter configurações
log "Obtendo configurações..."
cd terraform
APP_NAME=$(terraform output -raw codedeploy_application_name)
BUCKET=$(terraform output -raw s3_bucket_name)

# Obter deployment groups de forma mais direta
DG1=$(terraform output -json codedeploy_deployment_group_names | jq -r '.g1')
DG2=$(terraform output -json codedeploy_deployment_group_names | jq -r '.g2')
cd ..

DEPLOYMENT_GROUPS=($DG1 $DG2)

info "Aplicação: $APP_NAME"
info "Bucket S3: $BUCKET"
info "Deployment Groups: ${DEPLOYMENT_GROUPS[*]}"

# 4. Upload
log "Fazendo upload para S3..."
S3_KEY="deploy-all/$(date +%Y%m%d-%H%M%S).zip"
aws s3 cp deploy-all.zip "s3://$BUCKET/$S3_KEY" --quiet

# 5. Deploy em todos os grupos
log "Criando deployments em ${#DEPLOYMENT_GROUPS[@]} grupo(s)..."
DEPLOYMENT_IDS=()

for group in "${DEPLOYMENT_GROUPS[@]}"; do
    log "Criando deployment para: $group"
    
    DEPLOY_ID=$(aws deploy create-deployment \
        --application-name "$APP_NAME" \
        --deployment-group-name "$group" \
        --s3-location bucket="$BUCKET",key="$S3_KEY",bundleType=zip \
        --description "Deploy automático $(date '+%Y-%m-%d %H:%M:%S') - Grupo: $group" \
        --query 'deploymentId' --output text)
    
    DEPLOYMENT_IDS+=("$DEPLOY_ID")
    info "✓ Deployment ID para $group: $DEPLOY_ID"
done

# 6. Monitor todos os deployments
log "Monitorando ${#DEPLOYMENT_IDS[@]} deployment(s)..."

completed=0
total=${#DEPLOYMENT_IDS[@]}
attempts=0
max_attempts=30  # 15 minutos

while [ $completed -lt $total ] && [ $attempts -lt $max_attempts ]; do
    sleep 30
    attempts=$((attempts + 1))
    
    for i in "${!DEPLOYMENT_IDS[@]}"; do
        deploy_id="${DEPLOYMENT_IDS[$i]}"
        group="${DEPLOYMENT_GROUPS[$i]}"
        
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
    
    info "Progresso: $completed/$total concluídos ($attempts/$max_attempts tentativas)"
done

echo ""

# 7. Verificar resultados finais
failed=0
succeeded=0

for i in "${!DEPLOYMENT_IDS[@]}"; do
    deploy_id="${DEPLOYMENT_IDS[$i]}"
    group="${DEPLOYMENT_GROUPS[$i]}"
    status_file="/tmp/deploy_status_${deploy_id}"
    status=$(cat "$status_file" 2>/dev/null || echo "InProgress")
    
    case $status in
        "Succeeded")
            succeeded=$((succeeded + 1))
            ;;
        "Failed"|"Stopped")
            failed=$((failed + 1))
            error "Falha em $group: $deploy_id"
            ;;
        "InProgress")
            warning "Ainda em progresso: $group ($deploy_id)"
            ;;
    esac
    
    # Limpar arquivo temporário
    rm -f "$status_file"
done

# 8. Resultados finais
if [ $failed -eq 0 ] && [ $succeeded -eq $total ]; then
    log "🎉 TODOS OS DEPLOYMENTS CONCLUÍDOS COM SUCESSO!"
    rm -f deploy-all.zip
    
    echo ""
    warning "Para validar todos os deployments, execute:"
    echo "  ./validate_instances.sh"
    echo ""
    warning "Para testar os endpoints:"
    terraform output -raw instance_public_ips | jq -r '.[]' | head -1 | xargs -I {} echo "  curl http://{}:8080/healthcheck"
    
elif [ $failed -gt 0 ]; then
    error "❌ $failed deployment(s) falharam, $succeeded tiveram sucesso!"
    
    echo ""
    info "Para verificar detalhes dos erros:"
    for i in "${!DEPLOYMENT_IDS[@]}"; do
        deploy_id="${DEPLOYMENT_IDS[$i]}"
        group="${DEPLOYMENT_GROUPS[$i]}"
        status_file="/tmp/deploy_status_${deploy_id}"
        status=$(cat "$status_file" 2>/dev/null || echo "Unknown")
        if [ "$status" = "Failed" ] || [ "$status" = "Stopped" ]; then
            echo "  aws deploy get-deployment --deployment-id $deploy_id"
        fi
    done
    
    exit 1
    
else
    warning "⏰ Timeout ou deployments incompletos"
    echo ""
    info "Status atual:"
    for i in "${!DEPLOYMENT_IDS[@]}"; do
        deploy_id="${DEPLOYMENT_IDS[$i]}"
        group="${DEPLOYMENT_GROUPS[$i]}"
        status_file="/tmp/deploy_status_${deploy_id}"
        status=$(cat "$status_file" 2>/dev/null || echo "Unknown")
        echo "  $group: $status ($deploy_id)"
        rm -f "$status_file"
    done
    
    exit 1
fi
