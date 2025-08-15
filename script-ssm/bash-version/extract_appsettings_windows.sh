#!/bin/bash

# Script para extrair arquivos appsettings.json de servidores Windows via SSM
# Autor: AWS Terraform EC2 CodeDeploy Project
# Data: $(date +%Y-%m-%d)

set -e

# Configurações
AWS_PROFILE="${AWS_PROFILE:-default}"
SERVER_NAME_FILTER="SI2"
TARGET_PATH="D:\\Sites\\Api"
LOCAL_BACKUP_DIR="./config_backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="./logs/extract_appsettings_$(date +%Y%m%d_%H%M%S).log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar se AWS CLI está instalado
    if ! command -v aws &> /dev/null; then
        error "AWS CLI não está instalado. Por favor, instale primeiro."
        exit 1
    fi
    
    # Verificar se o profile existe
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        error "Profile AWS '$AWS_PROFILE' não configurado ou sem permissões."
        exit 1
    fi
    
    # Criar diretórios necessários
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$LOCAL_BACKUP_DIR"
    
    success "Pré-requisitos verificados com sucesso"
}

# Função para listar instâncias Windows com SI2 no nome
get_windows_instances() {
    log "Buscando instâncias Windows com '$SERVER_NAME_FILTER' no nome..."
    
    local instances
    instances=$(aws ec2 describe-instances \
        --profile "$AWS_PROFILE" \
        --filters \
            "Name=platform,Values=windows" \
            "Name=instance-state-name,Values=running" \
            "Name=tag:Name,Values=*${SERVER_NAME_FILTER}*" \
        --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,PublicIpAddress]' \
        --output text)
    
    if [ -z "$instances" ]; then
        warning "Nenhuma instância Windows encontrada com '$SERVER_NAME_FILTER' no nome"
        return 1
    fi
    
    echo "$instances"
}

# Função para verificar se a instância tem SSM ativo
check_ssm_status() {
    local instance_id=$1
    local name=$2
    
    log "Verificando status SSM para $name ($instance_id)..."
    
    local ssm_status
    ssm_status=$(aws ssm describe-instance-information \
        --profile "$AWS_PROFILE" \
        --instance-information-filter-list \
            key=InstanceIds,valueSet="$instance_id" \
        --query 'InstanceInformationList[0].PingStatus' \
        --output text 2>/dev/null || echo "NotFound")
    
    if [ "$ssm_status" = "Online" ]; then
        success "SSM ativo para $name ($instance_id)"
        return 0
    else
        warning "SSM não ativo ou não disponível para $name ($instance_id) - Status: $ssm_status"
        return 1
    fi
}

# Função para extrair hostname da instância
get_instance_hostname() {
    local instance_id=$1
    
    log "Obtendo hostname da instância $instance_id..."
    
    local hostname
    hostname=$(aws ssm send-command \
        --profile "$AWS_PROFILE" \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunPowerShellScript" \
        --parameters 'commands=hostname' \
        --query 'Command.CommandId' \
        --output text)
    
    # Aguardar execução
    sleep 3
    
    local result
    result=$(aws ssm get-command-invocation \
        --profile "$AWS_PROFILE" \
        --command-id "$hostname" \
        --instance-id "$instance_id" \
        --query 'StandardOutputContent' \
        --output text 2>/dev/null || echo "unknown")
    
    echo "$result" | tr -d '\r\n'
}

# Função para verificar se o diretório existe na instância
check_directory_exists() {
    local instance_id=$1
    local directory=$2
    
    log "Verificando se diretório $directory existe na instância $instance_id..."
    
    local command_id
    command_id=$(aws ssm send-command \
        --profile "$AWS_PROFILE" \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunPowerShellScript" \
        --parameters "commands=Test-Path '$directory'" \
        --query 'Command.CommandId' \
        --output text)
    
    # Aguardar execução
    sleep 3
    
    local result
    result=$(aws ssm get-command-invocation \
        --profile "$AWS_PROFILE" \
        --command-id "$command_id" \
        --instance-id "$instance_id" \
        --query 'StandardOutputContent' \
        --output text 2>/dev/null || echo "False")
    
    [ "$result" = "True" ]
}

# Função para listar arquivos appsettings na instância
list_appsettings_files() {
    local instance_id=$1
    local directory=$2
    
    log "Listando arquivos appsettings.json em $directory na instância $instance_id..."
    
    local command_id
    command_id=$(aws ssm send-command \
        --profile "$AWS_PROFILE" \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunPowerShellScript" \
        --parameters "commands=Get-ChildItem -Path '$directory' -Filter 'appsettings*.json' | Select-Object -ExpandProperty Name" \
        --query 'Command.CommandId' \
        --output text)
    
    # Aguardar execução
    sleep 3
    
    local result
    result=$(aws ssm get-command-invocation \
        --profile "$AWS_PROFILE" \
        --command-id "$command_id" \
        --instance-id "$instance_id" \
        --query 'StandardOutputContent' \
        --output text 2>/dev/null || echo "")
    
    echo "$result"
}

# Função para copiar arquivo da instância
copy_file_from_instance() {
    local instance_id=$1
    local remote_file=$2
    local local_file=$3
    local server_name=$4
    
    log "Copiando $remote_file de $server_name para $local_file..."
    
    # Primeiro, ler o conteúdo do arquivo
    local command_id
    command_id=$(aws ssm send-command \
        --profile "$AWS_PROFILE" \
        --instance-ids "$instance_id" \
        --document-name "AWS-RunPowerShellScript" \
        --parameters "commands=Get-Content -Path '$remote_file' -Raw" \
        --query 'Command.CommandId' \
        --output text)
    
    # Aguardar execução
    sleep 5
    
    local content
    content=$(aws ssm get-command-invocation \
        --profile "$AWS_PROFILE" \
        --command-id "$command_id" \
        --instance-id "$instance_id" \
        --query 'StandardOutputContent' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$content" ]; then
        echo "$content" > "$local_file"
        success "Arquivo copiado: $local_file"
        return 0
    else
        error "Falha ao copiar arquivo $remote_file de $server_name"
        return 1
    fi
}

# Função principal para processar uma instância
process_instance() {
    local instance_id=$1
    local instance_name=$2
    local private_ip=$3
    local public_ip=$4
    
    log "Processando instância: $instance_name ($instance_id)"
    log "IPs: Privado=$private_ip, Público=$public_ip"
    
    # Verificar status SSM
    if ! check_ssm_status "$instance_id" "$instance_name"; then
        return 1
    fi
    
    # Obter hostname
    local hostname
    hostname=$(get_instance_hostname "$instance_id")
    log "Hostname obtido: $hostname"
    
    # Verificar se diretório existe
    if ! check_directory_exists "$instance_id" "$TARGET_PATH"; then
        warning "Diretório $TARGET_PATH não existe na instância $instance_name"
        return 1
    fi
    
    # Listar arquivos appsettings
    local files
    files=$(list_appsettings_files "$instance_id" "$TARGET_PATH")
    
    if [ -z "$files" ]; then
        warning "Nenhum arquivo appsettings.json encontrado em $TARGET_PATH na instância $instance_name"
        return 1
    fi
    
    log "Arquivos encontrados em $instance_name:"
    echo "$files"
    
    # Validar se encontrou arquivos
    local file_count
    file_count=$(echo "$files" | grep -c "appsettings*\.json" 2>/dev/null || echo "0")
    log "Total de arquivos appsettings encontrados: $file_count"
    
    # Criar diretório para esta instância
    local instance_backup_dir="$LOCAL_BACKUP_DIR/$instance_name"
    mkdir -p "$instance_backup_dir"
    
    # Copiar TODOS os arquivos appsettings encontrados
    local files_copied=0
    
    # Extrair lista de arquivos da saída (filtrar e limpar)
    local file_list
    file_list=$(echo "$files" | grep -E "^appsettings.*\.json$" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v "^$")
    
    if [ -n "$file_list" ]; then
        log "Baixando arquivos appsettings encontrados..."
        
        # Processar cada arquivo encontrado
        while IFS= read -r filename; do
            if [ -n "$filename" ] && [[ "$filename" =~ ^appsettings.*\.json$ ]]; then
                log "Processando arquivo: $filename"
                
                local remote_path="$TARGET_PATH\\$filename"
                local local_path="$instance_backup_dir/$filename"
                
                if copy_file_from_instance "$instance_id" "$remote_path" "$local_path" "$instance_name"; then
                    ((files_copied++))
                    success "✓ Baixado: $filename"
                else
                    warning "✗ Falha ao baixar: $filename"
                fi
            fi
        done <<< "$file_list"
    else
        # Fallback: tentar baixar os arquivos padrão se a listagem falhou
        warning "Lista de arquivos vazia, tentando arquivos padrão..."
        
        # appsettings.json
        local appsettings_path="$TARGET_PATH\\appsettings.json"
        if copy_file_from_instance "$instance_id" "$appsettings_path" "$instance_backup_dir/appsettings.json" "$instance_name"; then
            ((files_copied++))
        fi
        
        # appsettings.<hostname>.json
        local hostname_settings_path="$TARGET_PATH\\appsettings.$hostname.json"
        if copy_file_from_instance "$instance_id" "$hostname_settings_path" "$instance_backup_dir/appsettings.$hostname.json" "$instance_name"; then
            ((files_copied++))
        fi
    fi
    
    # Criar arquivo de metadados
    cat > "$instance_backup_dir/metadata.txt" << EOF
Instance ID: $instance_id
Instance Name: $instance_name
Hostname: $hostname
Private IP: $private_ip
Public IP: $public_ip
Target Path: $TARGET_PATH
Extraction Date: $(date)
Files Copied: $files_copied
EOF
    
    success "Processamento concluído para $instance_name - $files_copied arquivos copiados"
    
    # Listar arquivos baixados para esta instância
    if [ $files_copied -gt 0 ]; then
        log "Arquivos baixados de $instance_name:"
        find "$instance_backup_dir" -name "appsettings*.json" -type f | while read -r file; do
            local basename_file=$(basename "$file")
            local size=$(du -h "$file" | cut -f1)
            log "  ✓ $basename_file ($size)"
        done
    fi
}

# Função principal
main() {
    log "Iniciando extração de arquivos appsettings.json"
    log "Profile AWS: $AWS_PROFILE"
    log "Filtro de servidor: $SERVER_NAME_FILTER"
    log "Diretório de backup: $LOCAL_BACKUP_DIR"
    
    # Verificar pré-requisitos
    check_prerequisites
    
    # Obter lista de instâncias
    local instances
    if ! instances=$(get_windows_instances); then
        error "Falha ao obter lista de instâncias"
        exit 1
    fi
    
    log "Instâncias encontradas:"
    echo "$instances"
    
    # Processar cada instância
    local total_processed=0
    local total_successful=0
    
    while IFS=$'\t' read -r instance_id instance_name private_ip public_ip; do
        if [ -n "$instance_id" ]; then
            ((total_processed++))
            log "--- Processando instância $total_processed ---"
            
            if process_instance "$instance_id" "$instance_name" "$private_ip" "$public_ip"; then
                ((total_successful++))
            fi
            
            log "--- Fim do processamento da instância $total_processed ---"
            echo
        fi
    done <<< "$instances"
    
    # Resumo final
    log "=== RESUMO FINAL ==="
    log "Total de instâncias processadas: $total_processed"
    log "Total de instâncias com sucesso: $total_successful"
    log "Arquivos salvos em: $LOCAL_BACKUP_DIR"
    log "Log completo em: $LOG_FILE"
    
    # Listar arquivos copiados
    if [ $total_successful -gt 0 ]; then
        log "Arquivos extraídos:"
        find "$LOCAL_BACKUP_DIR" -name "*.json" -type f | sort
    fi
    
    success "Extração concluída!"
}

# Verificar argumentos
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Uso: $0 [AWS_PROFILE]"
    echo ""
    echo "Extrai arquivos appsettings.json de servidores Windows AWS via SSM"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  AWS_PROFILE    - Profile AWS a usar (padrão: default)"
    echo ""
    echo "Exemplo:"
    echo "  AWS_PROFILE=meu-profile $0"
    echo "  $0 meu-profile"
    exit 0
fi

# Permitir passar profile como argumento
if [ -n "$1" ]; then
    AWS_PROFILE="$1"
fi

# Executar função principal
main
