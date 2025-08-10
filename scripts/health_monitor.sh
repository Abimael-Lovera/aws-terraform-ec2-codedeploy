#!/bin/bash

# health_monitor.sh
# Script para monitoramento contínuo da saúde da aplicação
# Pode ser usado para verificações regulares ou troubleshooting

set -e

# Configurações
KEY_FILE="contador-app-key-ssh.pem"
USER="ec2-user"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Função para executar comando SSH
ssh_exec() {
    local host=$1
    local command=$2
    timeout 15 ssh $SSH_OPTIONS -i "$KEY_FILE" "$USER@$host" "$command"
}

# Função para testar conectividade básica
test_connectivity() {
    local host=$1
    
    if timeout 5 ssh $SSH_OPTIONS -i "$KEY_FILE" "$USER@$host" "echo 'SSH OK'" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Função para obter status detalhado de uma instância
get_instance_status() {
    local host=$1
    local instance_name=$2
    
    log "=== Status da instância $instance_name ($host) ==="
    
    # Teste de conectividade
    if ! test_connectivity "$host"; then
        error "❌ SSH não acessível"
        return 1
    fi
    echo "✓ SSH acessível"
    
    # Status da aplicação
    local app_status
    app_status=$(ssh_exec "$host" "sudo systemctl is-active contador-app 2>/dev/null || echo 'not-found'")
    
    if [ "$app_status" = "active" ]; then
        echo "✓ Aplicação ativa"
        
        # Testar endpoints
        local health_check
        health_check=$(ssh_exec "$host" "curl -s -w '%{http_code}' http://localhost:8080/healthcheck 2>/dev/null || echo 'ERRO'")
        
        if echo "$health_check" | grep -q "200$"; then
            local response_body
            response_body=$(echo "$health_check" | sed 's/200$//')
            echo "✓ Endpoint /healthcheck: $response_body (HTTP 200)"
        else
            error "❌ Endpoint /healthcheck falhou: $health_check"
        fi
        
        local counter_check
        counter_check=$(ssh_exec "$host" "curl -s -w '%{http_code}' http://localhost:8080/contador 2>/dev/null || echo 'ERRO'")
        
        if echo "$counter_check" | grep -q "200$"; then
            local counter_body
            counter_body=$(echo "$counter_check" | sed 's/200$//')
            echo "✓ Endpoint /contador: $counter_body (HTTP 200)"
        else
            error "❌ Endpoint /contador falhou: $counter_check"
        fi
        
    elif [ "$app_status" = "not-found" ]; then
        warning "⚠ Aplicação não deployada"
    else
        error "❌ Aplicação não está ativa: $app_status"
        
        # Mostrar logs se aplicação não estiver rodando
        local service_status
        service_status=$(ssh_exec "$host" "sudo systemctl status contador-app --no-pager -l 2>/dev/null || echo 'Service não encontrado'")
        echo "Status do serviço:"
        echo "$service_status" | head -15
    fi
    
    # Recursos do sistema
    local system_load
    system_load=$(ssh_exec "$host" "uptime | awk -F'load average:' '{print \$2}' | sed 's/^[ \\t]*//'")
    echo "📊 Load average: $system_load"
    
    local memory_usage
    memory_usage=$(ssh_exec "$host" "free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}'")
    echo "💾 Uso de memória: $memory_usage"
    
    local disk_usage
    disk_usage=$(ssh_exec "$host" "df / | awk 'NR==2 {print \$5}'")
    echo "💽 Uso de disco: $disk_usage"
    
    # Logs recentes da aplicação (se existir)
    local recent_logs
    recent_logs=$(ssh_exec "$host" "sudo tail -3 /var/log/app.log 2>/dev/null || echo 'Log não disponível'")
    if [ "$recent_logs" != "Log não disponível" ]; then
        echo "📋 Últimas linhas do log:"
        echo "$recent_logs"
    fi
    
    echo ""
    return 0
}

# Função para monitoramento contínuo
continuous_monitor() {
    local interval=${1:-30}  # Intervalo padrão de 30 segundos
    
    log "Iniciando monitoramento contínuo (intervalo: ${interval}s)"
    log "Pressione Ctrl+C para parar"
    echo ""
    
    while true; do
        monitor_all_instances
        echo "=================================="
        log "Próxima verificação em ${interval}s..."
        sleep "$interval"
        clear
    done
}

# Função para monitorar todas as instâncias
monitor_all_instances() {
    cd "$PROJECT_ROOT/terraform"
    
    local instance_ips
    instance_ips=$(terraform output -json instance_public_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
    
    if [ -z "$instance_ips" ]; then
        error "Não foi possível obter IPs das instâncias"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    
    local instance_count=0
    local healthy_count=0
    
    for ip in $instance_ips; do
        instance_count=$((instance_count + 1))
        
        if get_instance_status "$ip" "Instance-$instance_count"; then
            healthy_count=$((healthy_count + 1))
        fi
    done
    
    # Resumo
    log "=== RESUMO DO MONITORAMENTO ==="
    log "Instâncias: $instance_count | Saudáveis: $healthy_count | Problemas: $((instance_count - healthy_count))"
    
    if [ $healthy_count -eq $instance_count ]; then
        log "🟢 Todas as instâncias estão saudáveis"
    else
        warning "🟡 Algumas instâncias têm problemas"
    fi
}

# Função para teste de carga simples
load_test() {
    local requests=${1:-10}
    local endpoint=${2:-"/contador"}
    
    log "Executando teste de carga simples..."
    log "Requests: $requests | Endpoint: $endpoint"
    
    cd "$PROJECT_ROOT/terraform"
    
    local instance_ips
    instance_ips=$(terraform output -json instance_public_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
    
    if [ -z "$instance_ips" ]; then
        error "Não foi possível obter IPs das instâncias"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    
    for ip in $instance_ips; do
        log "Testando instância $ip..."
        
        local success_count=0
        local start_time
        start_time=$(date +%s)
        
        for i in $(seq 1 "$requests"); do
            local response
            response=$(ssh_exec "$ip" "curl -s -w '%{http_code}' http://localhost:8080$endpoint" 2>/dev/null || echo "ERRO")
            
            if echo "$response" | grep -q "200$"; then
                success_count=$((success_count + 1))
                echo -n "."
            else
                echo -n "E"
            fi
        done
        
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        log "Resultado: $success_count/$requests sucessos em ${duration}s"
        
        if [ $success_count -eq "$requests" ]; then
            echo "✓ Todos os requests foram bem-sucedidos"
        else
            warning "❌ Alguns requests falharam"
        fi
        echo ""
    done
}

# Função de ajuda
show_help() {
    echo "Uso: $0 [COMANDO] [OPÇÕES]"
    echo ""
    echo "Comandos:"
    echo "  status                    Mostra status atual de todas as instâncias"
    echo "  monitor [INTERVALO]       Monitoramento contínuo (padrão: 30s)"
    echo "  load-test [REQUESTS] [ENDPOINT]  Teste de carga simples (padrão: 10 requests em /contador)"
    echo "  help                      Mostra esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 status                 # Status único"
    echo "  $0 monitor 60             # Monitoramento a cada 60s"
    echo "  $0 load-test 50 /healthcheck  # 50 requests no /healthcheck"
    echo ""
    echo "Pré-requisitos:"
    echo "  - Chave SSH '$KEY_FILE' no diretório raiz"
    echo "  - Terraform com estado válido"
    echo "  - jq instalado"
}

# Função principal
main() {
    local command=${1:-status}
    
    # Verificar dependências
    if ! command -v jq > /dev/null 2>&1; then
        error "jq não está instalado"
        echo "Instale com: brew install jq"
        exit 1
    fi
    
    if ! command -v terraform > /dev/null 2>&1; then
        error "terraform não está instalado"
        exit 1
    fi
    
    # Verificar chave SSH
    if [ ! -f "$PROJECT_ROOT/$KEY_FILE" ]; then
        error "Chave SSH '$KEY_FILE' não encontrada no diretório raiz"
        exit 1
    fi
    
    # Executar comando
    case "$command" in
        status)
            monitor_all_instances
            ;;
        monitor)
            local interval=${2:-30}
            continuous_monitor "$interval"
            ;;
        load-test)
            local requests=${2:-10}
            local endpoint=${3:-"/contador"}
            load_test "$requests" "$endpoint"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Comando inválido: $command"
            show_help
            exit 1
            ;;
    esac
}

# Configurar trap para Ctrl+C no monitoramento contínuo
trap 'log "Monitoramento interrompido pelo usuário"; exit 0' INT

# Executar função principal
main "$@"
